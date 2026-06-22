from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from typing import List

from ..database import get_db
from ..models import Meeting, MeetingResponse, Message, User
from ..schemas import MessageCreate, MessageResponse
from ..dependencies import get_current_user
from ..websocket_manager import manager  # 🆕 Импортируем менеджер WebSocket

router = APIRouter(prefix="/messages", tags=["Messages"])

# 1. Отправить сообщение
@router.post("/", response_model=MessageResponse)
async def send_message(
    data: MessageCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Проверяем, что встреча существует
    meeting = await db.get(Meeting, data.meeting_id)
    if not meeting:
        raise HTTPException(status_code=404, detail="Встреча не найдена")
    
    # Проверяем, что встреча не отменена
    if meeting.status == "cancelled":
        raise HTTPException(status_code=400, detail="Встреча отменена")
    
    # Проверяем право писать в этот чат
    is_author = meeting.user_id == current_user.id
    
    stmt = select(MeetingResponse).where(
        MeetingResponse.meeting_id == data.meeting_id,
        MeetingResponse.user_id == current_user.id,
        MeetingResponse.status.in_(["pending", "accepted", "confirmed"])
    )
    result = await db.execute(stmt)
    response = result.scalar_one_or_none()
    
    if not is_author and not response:
        raise HTTPException(status_code=403, detail="У вас нет доступа к этому чату")
    
    # Создаем сообщение
    new_message = Message(
        meeting_id=data.meeting_id,
        sender_id=current_user.id,
        text=data.text,
        is_read=False
    )
    db.add(new_message)
    await db.commit()
    await db.refresh(new_message)

    # 🆕 РАССЫЛАЕМ СООБЩЕНИЕ ЧЕРЕЗ WEBSOCKET ВСЕМ В КОМНАТЕ!
    await manager.broadcast(str(data.meeting_id), {
        "type": "new_message",
        "id": str(new_message.id),
        "text": data.text,
        "sender_id": str(current_user.id),
        "sender_username": current_user.username,
        "sender_avatar_url": current_user.avatar_url,
        "is_read": False,
        "created_at": new_message.created_at.isoformat()
    })

    # 🆕 Отправляем Push-уведомление другим участникам чата
    from app.services.push_service import send_push_notification
    
    participants = []
    
    if meeting.user_id != current_user.id:
        author = await db.get(User, meeting.user_id)
        if author and author.fcm_token:
            participants.append(author)
    
    if is_author:
        stmt = select(MeetingResponse).where(
            MeetingResponse.meeting_id == data.meeting_id,
            MeetingResponse.status.in_(["pending", "accepted", "confirmed"])
        ).limit(1)
        result = await db.execute(stmt)
        responder_response = result.scalar_one_or_none()
        
        if responder_response:
            responder = await db.get(User, responder_response.user_id)
            if responder and responder.fcm_token and responder.id != current_user.id:
                participants.append(responder)
    
    for participant in participants:
        if participant.notify_messages:
            await send_push_notification(
                fcm_token=participant.fcm_token,
                title="Новое сообщение 💬",
                body=f"{current_user.username}: {data.text[:50]}{'...' if len(data.text) > 50 else ''}",
                data={
                    "type": "new_message",
                    "meeting_id": str(data.meeting_id)
                }
            )

    return MessageResponse(
        id=new_message.id,
        meeting_id=new_message.meeting_id,
        sender_id=new_message.sender_id,
        text=new_message.text,
        is_read=new_message.is_read,
        created_at=new_message.created_at,
        sender_username=current_user.username,
        sender_avatar_url=current_user.avatar_url
    )

# 2. Получить историю сообщений для встречи
@router.get("/meeting/{meeting_id}", response_model=List[MessageResponse])
async def get_meeting_messages(
    meeting_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    meeting = await db.get(Meeting, meeting_id)
    if not meeting:
        raise HTTPException(status_code=404, detail="Встреча не найдена")
    
    is_author = meeting.user_id == current_user.id
    
    stmt = select(MeetingResponse).where(
        MeetingResponse.meeting_id == meeting_id,
        MeetingResponse.user_id == current_user.id,
        MeetingResponse.status.in_(["pending", "accepted", "confirmed"])
    )
    result = await db.execute(stmt)
    response = result.scalar_one_or_none()
    
    if not is_author and not response:
        raise HTTPException(status_code=403, detail="У вас нет доступа к этому чату")
    
    stmt = select(Message, User).join(User, Message.sender_id == User.id).where(
        Message.meeting_id == meeting_id
    ).order_by(Message.created_at.asc())
    
    result = await db.execute(stmt)
    messages_data = result.all()
    
    messages = []
    for msg, sender in messages_data:
        messages.append(MessageResponse(
            id=msg.id,
            meeting_id=msg.meeting_id,
            sender_id=msg.sender_id,
            text=msg.text,
            is_read=msg.is_read,
            created_at=msg.created_at,
            sender_username=sender.username,
            sender_avatar_url=sender.avatar_url
        ))
    
    return messages

# 3. Пометить сообщения как прочитанные
@router.put("/meeting/{meeting_id}/read")
async def mark_messages_as_read(
    meeting_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Message).where(
        Message.meeting_id == meeting_id,
        Message.sender_id != current_user.id,
        Message.is_read == False
    )
    result = await db.execute(stmt)
    messages = result.scalars().all()
    
    for msg in messages:
        msg.is_read = True
    
    await db.commit()
    
    # 🆕 Рассылаем обновление статусов прочтения через WebSocket
    await manager.broadcast(str(meeting_id), {
        "type": "messages_read",
        "reader_id": str(current_user.id)
    })
    
    return {"message": f"Помечено как прочитано: {len(messages)} сообщений"}

# 4. Получить список всех моих чатов
@router.get("/my", response_model=List[dict])
async def get_my_chats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Meeting).where(Meeting.user_id == current_user.id)
    result = await db.execute(stmt)
    my_meetings_as_author = result.scalars().all()
    
    stmt = select(Meeting).join(MeetingResponse).where(
        MeetingResponse.user_id == current_user.id,
        MeetingResponse.status.in_(["pending","accepted", "confirmed"])
    )
    result = await db.execute(stmt)
    my_meetings_as_responder = result.scalars().all()
    
    all_meetings = {m.id: m for m in my_meetings_as_author + my_meetings_as_responder}.values()

    meetings_with_messages = []
    for meeting in all_meetings:
        stmt = select(Message).where(Message.meeting_id == meeting.id).limit(1)
        result = await db.execute(stmt)
        if result.scalar_one_or_none() is not None:
            meetings_with_messages.append(meeting)

    all_meetings = meetings_with_messages
    
    chats = []
    for meeting in all_meetings:
        stmt = select(Message).where(Message.meeting_id == meeting.id).order_by(Message.created_at.desc()).limit(1)
        result = await db.execute(stmt)
        last_message = result.scalar_one_or_none()
        
        if meeting.user_id == current_user.id:
            stmt = select(User).join(MeetingResponse).where(
                MeetingResponse.meeting_id == meeting.id,
                MeetingResponse.status.in_(["pending", "accepted", "confirmed"])
            ).limit(1)
            result = await db.execute(stmt)
            opponent = result.scalar_one_or_none()
        else:
            opponent = await db.get(User, meeting.user_id)
        
        opponent_name = opponent.username if opponent else "Собеседник"
        opponent_avatar = opponent.avatar_url if opponent else None
        
        stmt = select(Message).where(
            Message.meeting_id == meeting.id,
            Message.sender_id != current_user.id,
            Message.is_read == False
        )
        result = await db.execute(stmt)
        unread_count = len(result.scalars().all())
        
        chats.append({
            "meeting_id": str(meeting.id),
            "meeting_title": meeting.title,
            "opponent_name": opponent_name,
            "opponent_avatar_url": opponent_avatar,
            "last_message": last_message.text if last_message else None,
            "last_message_time": last_message.created_at.isoformat() if last_message else None,
            "unread_count": unread_count
        })
    
    chats.sort(key=lambda x: x['last_message_time'] or '', reverse=True)
    
    return chats