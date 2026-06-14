from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from typing import List
from datetime import date
import uuid
from fastapi import status
from sqlalchemy import update

from ..database import get_db
from ..models import Meeting, MeetingResponse, User
from ..schemas import MeetingResponseCreate, MeetingResponseInfo

from ..dependencies import get_current_user 

router = APIRouter(prefix="/responses", tags=["Responses"])

# 1. Создать отклик
@router.post("/", response_model=MeetingResponseInfo)
async def create_response(
    data: MeetingResponseCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Проверяем, что встреча существует
    meeting = await db.get(Meeting, data.meeting_id)
    if not meeting:
        raise HTTPException(status_code=404, detail="Встреча не найдена")
    
    # Нельзя откликаться на свою же встречу
    if meeting.user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Нельзя откликаться на свою встречу")

     # Проверяем, не откликался ли уже (исключаем отменённые и отклонённые заявки)
    stmt = select(MeetingResponse).where(
        MeetingResponse.meeting_id == data.meeting_id,
        MeetingResponse.user_id == current_user.id,
        MeetingResponse.status.in_(["pending", "accepted", "confirmed"]) # 🆕 Только активные статусы!
    )
    result = await db.execute(stmt)
    existing_response = result.scalar_one_or_none()
    
    if existing_response:
        raise HTTPException(status_code=400, detail="Вы уже откликнулись на эту встречу")

    # Создаем отклик
    new_response = MeetingResponse(
        meeting_id=data.meeting_id,
        user_id=current_user.id,
        response_message=data.response_message,
        status="pending"
    )
    db.add(new_response)
    await db.commit()
    await db.refresh(new_response)

    # Считаем возраст для ответа
    age = None
    if current_user.birth_date:
        today = date.today()
        age = today.year - current_user.birth_date.year - ((today.month, today.day) < (current_user.birth_date.month, current_user.birth_date.day))

        # 🆕 Отправляем Push-уведомление автору встречи!
    from app.services.push_service import send_push_notification
    
    # Находим автора встречи, чтобы взять его токен
    creator = await db.get(User, meeting.user_id)
    if creator and creator.fcm_token:
        await send_push_notification(
            fcm_token=creator.fcm_token,
            title="Новый отклик! 💕",
            body=f"{current_user.username} хочет пойти на '{meeting.title}'"
        )

    return MeetingResponseInfo(
        id=new_response.id,
        meeting_id=new_response.meeting_id,
        user_id=new_response.user_id,
        status=new_response.status,
        response_message=new_response.response_message,
        created_at=new_response.created_at,
        responder_username=current_user.username,
        responder_avatar_url=current_user.avatar_url,
        responder_age=age,
        responder_gender=current_user.gender
    )

# 2. Получить отклики для встречи (только для автора)
@router.get("/meeting/{meeting_id}", response_model=List[MeetingResponseInfo])
async def get_meeting_responses(
    meeting_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    meeting = await db.get(Meeting, meeting_id)
    if not meeting or meeting.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Встреча не найдена или вы не её автор")

    stmt = select(MeetingResponse, User).join(User, MeetingResponse.user_id == User.id).where(
        MeetingResponse.meeting_id == meeting_id
    )
    result = await db.execute(stmt)
    responses_data = result.all()

    responses = []
    for resp, user in responses_data:
        age = None
        if user.birth_date:
            today = date.today()
            age = today.year - user.birth_date.year - ((today.month, today.day) < (user.birth_date.month, user.birth_date.day))

        responses.append(MeetingResponseInfo(
            id=resp.id,
            meeting_id=resp.meeting_id,
            user_id=resp.user_id,
            status=resp.status,
            response_message=resp.response_message,
            created_at=resp.created_at,
            responder_username=user.username,
            responder_avatar_url=user.avatar_url,
            responder_age=age,
            responder_gender=user.gender
        ))
    return responses

# 3. Изменить статус отклика (Принять/Отклонить/Подтвердить)
@router.put("/{response_id}/status")
async def update_response_status(
    response_id: UUID,
    new_status: str, # "accepted", "rejected", "confirmed"
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    resp = await db.get(MeetingResponse, response_id)
    if not resp:
        raise HTTPException(status_code=404, detail="Отклик не найден")

    meeting = await db.get(Meeting, resp.meeting_id)
    
    # Проверка прав
    if new_status in ["accepted", "rejected"]:
        if meeting.user_id != current_user.id:
            raise HTTPException(status_code=403, detail="Только автор встречи может менять этот статус")
    elif new_status == "confirmed":
        if resp.user_id != current_user.id:
            raise HTTPException(status_code=403, detail="Только откликнувшийся может подтвердить встречу")
    else:
        raise HTTPException(status_code=400, detail="Неверный статус")
    
    resp.status = new_status
    
    # Если статус confirmed, меняем статус самой встречи, чтобы она исчезла из ленты
    if new_status == "confirmed":
        meeting.status = "confirmed"

    await db.commit()
    await db.refresh(resp)
    return {"message": "Статус обновлен", "status": resp.status}

# 4. Получить мои отклики (заявки на чужие встречи)
@router.get("/my", response_model=List[MeetingResponseInfo])
async def get_my_responses(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # 🆕 Получаем только активные заявки (pending, accepted, confirmed). 
    # Отклонённые и отменённые уйдут в архив!
    stmt = select(MeetingResponse, Meeting, User).join(
        Meeting, MeetingResponse.meeting_id == Meeting.id
    ).join(
        User, Meeting.user_id == User.id
    ).where(
        MeetingResponse.user_id == current_user.id,
        MeetingResponse.status.in_(["pending", "accepted", "confirmed"]) # 🆕 Фильтр по статусу!
    ).order_by(MeetingResponse.created_at.desc())
    
    result = await db.execute(stmt)
    responses_data = result.all()

    responses = []
    for resp, meeting, creator in responses_data:
        age = None
        if creator.birth_date:
            today = date.today()
            age = today.year - creator.birth_date.year - ((today.month, today.day) < (creator.birth_date.month, creator.birth_date.day))

        # 🆕 Проверяем, есть ли сообщения в чате
        from ..models import Message
        stmt = select(Message).where(Message.meeting_id == meeting.id).limit(1)
        result = await db.execute(stmt)
        has_messages = result.scalar_one_or_none() is not None
        
        # 🆕 Добавляем полные данные о встрече
        meeting_data = {
            'id': str(meeting.id),
            'title': meeting.title,
            'description': meeting.description,
            'meeting_date': meeting.meeting_date.isoformat() if meeting.meeting_date else None,
            'meeting_time': meeting.meeting_time,
            'location': meeting.location,
            'partner_wishes': meeting.partner_wishes,
            'finance': meeting.finance,
            'status': meeting.status,
            'creator_id': str(creator.id),
            'creator_username': creator.username,
            'creator_age': age,
            'creator_gender': creator.gender,
            'creator_avatar_url': creator.avatar_url,
            'has_messages': has_messages,  # 🆕 Есть ли сообщения в чате
            'has_responded': True, 
        }

        responses.append(MeetingResponseInfo(
            id=resp.id,
            meeting_id=meeting.id,
            meeting_title=meeting.title,
            meeting=meeting_data,  # 🆕 Передаем полные данные о встрече
            user_id=resp.user_id,
            status=resp.status,
            response_message=resp.response_message,
            created_at=resp.created_at,
            responder_username=creator.username,
            responder_avatar_url=creator.avatar_url,
            responder_age=age,
            responder_gender=creator.gender
        ))
    return responses

# 🆕 Отменить свою заявку на встречу
@router.delete("/{response_id}")
async def cancel_response(
    response_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Ищем отклик
    stmt = select(MeetingResponse).where(MeetingResponse.id == response_id)
    result = await db.execute(stmt)
    response = result.scalar_one_or_none()
    
    if not response:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Отклик не найден")
    
    # Проверяем, что это именно МОЯ заявка
    if response.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Нельзя отменить чужую заявку")
        
    # Проверяем, что заявка ещё в ожидании (принятую или отклонённую отменять уже поздно)
    if response.status != "pending":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Можно отменить только заявку, которая ещё в ожидании")
    
    # Меняем статус на отменённый (или можно просто удалить, но статус лучше для истории)
    response.status = "cancelled"
    await db.commit()
    
    return {"message": "Заявка успешно отменена"}

# 5. Получить мои архивные отклики (завершённые)
@router.get("/my/archived", response_model=List[MeetingResponseInfo])
async def get_my_archived_responses(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # 🆕 Берём все заявки, кроме активных (pending, accepted, confirmed с будущей датой)
    stmt = select(MeetingResponse, Meeting, User).join(
        Meeting, MeetingResponse.meeting_id == Meeting.id
    ).join(
        User, Meeting.user_id == User.id
    ).where(
        MeetingResponse.user_id == current_user.id
    ).order_by(MeetingResponse.created_at.desc())
    
    result = await db.execute(stmt)
    responses_data = result.all()

    responses = []
    today = date.today()
    
    for resp, meeting, creator in responses_data:
        # 🆕 Фильтруем: в архив попадают только завершённые заявки
        # 1. Отклонённые и отменённые — всегда в архив
        # 2. Принятые и подтверждённые — только если дата встречи уже прошла
        is_archived = (
            resp.status in ["rejected", "cancelled"] or
            (resp.status in ["accepted", "confirmed"] and meeting.meeting_date and meeting.meeting_date < today)
        )
        
        if not is_archived:
            continue  # Пропускаем активные заявки
        
        age = None
        if creator.birth_date:
            age = today.year - creator.birth_date.year - ((today.month, today.day) < (creator.birth_date.month, creator.birth_date.day))
        
        # Формируем структуру meeting
        meeting_data = {
            'id': str(meeting.id),
            'title': meeting.title,
            'description': meeting.description,
            'meeting_date': meeting.meeting_date.isoformat() if meeting.meeting_date else None,
            'meeting_time': meeting.meeting_time,
            'location': meeting.location,
            'partner_wishes': meeting.partner_wishes,
            'finance': meeting.finance,
            'status': meeting.status,
            'creator_id': str(creator.id),
            'creator_username': creator.username,
            'creator_age': age,
            'creator_gender': creator.gender,
            'creator_avatar_url': creator.avatar_url,
            'has_messages': False,
            'has_responded': True,
        }

        responses.append(MeetingResponseInfo(
            id=resp.id,
            meeting_id=meeting.id,
            meeting_title=meeting.title,
            meeting=meeting_data,
            user_id=resp.user_id,
            status=resp.status,
            response_message=resp.response_message,
            created_at=resp.created_at,
            responder_username=creator.username,
            responder_avatar_url=creator.avatar_url,
            responder_age=age,
            responder_gender=creator.gender
        ))
    return responses

# 🆕 Пометить все отклики на встречу как прочитанные
@router.put("/mark-as-read/{meeting_id}")
async def mark_responses_as_read(
    meeting_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # 1. Проверяем, что встреча существует и принадлежит текущему пользователю
    stmt = select(Meeting).where(Meeting.id == meeting_id)
    result = await db.execute(stmt)
    meeting = result.scalar_one_or_none()
    
    if not meeting:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Встреча не найдена")
    
    if meeting.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Можно помечать только свои встречи")
    
   # 2. Помечаем только pending-отклики как прочитанные
    update_stmt = (
        update(MeetingResponse)
        .where(
            MeetingResponse.meeting_id == meeting_id,
            MeetingResponse.is_read == False,
            MeetingResponse.status == 'pending'  # 🆕 Только те, что ждут решения
        )
        .values(is_read=True)
    )
    
    await db.execute(update_stmt)
    await db.commit()
    
    return {"message": "Все отклики помечены как прочитанные"}