from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from typing import List

from ..database import get_db
from ..models import Meeting, MeetingResponse, Message, User
from ..schemas import MessageCreate, MessageResponse
from ..dependencies import get_current_user

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
    # Право имеют: автор встречи ИЛИ тот, кто откликнулся и был принят
    
    # Является ли текущий пользователь автором встречи?
    is_author = meeting.user_id == current_user.id
    
    # Откликался ли пользователь и был ли принят?
    stmt = select(MeetingResponse).where(
        MeetingResponse.meeting_id == data.meeting_id,
        MeetingResponse.user_id == current_user.id,
        MeetingResponse.status.in_(["accepted", "confirmed"])
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
    # Проверяем, что встреча существует
    meeting = await db.get(Meeting, meeting_id)
    if not meeting:
        raise HTTPException(status_code=404, detail="Встреча не найдена")
    
    # Проверяем право доступа к чату
    is_author = meeting.user_id == current_user.id
    
    stmt = select(MeetingResponse).where(
        MeetingResponse.meeting_id == meeting_id,
        MeetingResponse.user_id == current_user.id,
        MeetingResponse.status.in_(["accepted", "confirmed"])
    )
    result = await db.execute(stmt)
    response = result.scalar_one_or_none()
    
    if not is_author and not response:
        raise HTTPException(status_code=403, detail="У вас нет доступа к этому чату")
    
    # Получаем все сообщения для этой встречи
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
    # Находим все непрочитанные сообщения в этом чате, где отправитель НЕ текущий пользователь
    stmt = select(Message).where(
        Message.meeting_id == meeting_id,
        Message.sender_id != current_user.id,
        Message.is_read == False
    )
    result = await db.execute(stmt)
    messages = result.scalars().all()
    
    # Помечаем их как прочитанные
    for msg in messages:
        msg.is_read = True
    
    await db.commit()
    return {"message": f"Помечено как прочитано: {len(messages)} сообщений"}