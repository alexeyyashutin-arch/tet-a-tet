import uuid
from datetime import date
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import List

from ..database import get_db
from ..models import User, Meeting, MeetingResponse as MeetingResponseModel
from ..schemas import MeetingCreate, MeetingResponse, MyMeetingsResponse  # 🆕 Добавили новую схему
from ..dependencies import get_current_user

router = APIRouter(prefix="/meetings", tags=["Встречи"])

def calculate_age(birth_date) -> int | None:
    if not birth_date:
        return None
    today = date.today()
    age = today.year - birth_date.year
    if (today.month, today.day) < (birth_date.month, birth_date.day):
        age -= 1
    return age

@router.post("/", response_model=MeetingResponse, status_code=status.HTTP_201_CREATED)
async def create_meeting(
    data: MeetingCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if data.meeting_date < date.today():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Дата встречи не может быть в прошлом"
        )
    
    meeting = Meeting(
        user_id=current_user.id,
        title=data.title,
        description=data.description,
        meeting_date=data.meeting_date,
        meeting_time=data.meeting_time,
        location=data.location,
        partner_wishes=data.partner_wishes,
        finance=data.finance
    )
    
    db.add(meeting)
    await db.commit()
    await db.refresh(meeting)
    
    return MeetingResponse(
        id=meeting.id,
        user_id=meeting.user_id,
        title=meeting.title,
        description=meeting.description,
        meeting_date=meeting.meeting_date,
        meeting_time=meeting.meeting_time,
        location=meeting.location,
        partner_wishes=meeting.partner_wishes,
        finance=meeting.finance,
        status=meeting.status,
        created_at=meeting.created_at,
        creator_username=current_user.username,
        creator_avatar_url=current_user.avatar_url,
        creator_age=calculate_age(current_user.birth_date),
        creator_gender=current_user.gender, 
    )

@router.get("/", response_model=List[MeetingResponse])
async def get_active_meetings(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Meeting, User).join(User, Meeting.user_id == User.id).where(
        Meeting.status == "active"
    )
    
    if current_user.city:
        stmt = stmt.where(User.city == current_user.city)
        
    stmt = stmt.order_by(Meeting.meeting_date.asc(), Meeting.meeting_time.asc())
    
    result = await db.execute(stmt)
    meetings_data = result.all()
    
    meetings = []
    for meeting, user in meetings_data:
        resp_stmt = select(MeetingResponseModel).where(
            MeetingResponseModel.meeting_id == meeting.id,
            MeetingResponseModel.user_id == current_user.id
        )
        resp_result = await db.execute(resp_stmt)
        has_responded = resp_result.scalar_one_or_none() is not None

        meetings.append(MeetingResponse(
            id=meeting.id,
            user_id=meeting.user_id,
            creator_id=meeting.user_id,
            title=meeting.title,
            description=meeting.description,
            meeting_date=meeting.meeting_date,
            meeting_time=meeting.meeting_time,
            location=meeting.location,
            partner_wishes=meeting.partner_wishes,
            finance=meeting.finance,
            status=meeting.status,
            created_at=meeting.created_at,
            creator_username=user.username,
            creator_avatar_url=user.avatar_url,
            creator_age=calculate_age(user.birth_date),
            creator_gender=user.gender,
            has_responded=has_responded,
        ))
    
    return meetings

@router.get("/my", response_model=MyMeetingsResponse)  # 🆕 Изменили тип возврата
async def get_my_meetings(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Meeting).where(Meeting.user_id == current_user.id).order_by(
        Meeting.meeting_date.asc()
    )
    
    result = await db.execute(stmt)
    meetings = result.scalars().all()
    
    response_list = []
    total_unread = 0  # 🆕 Общий счётчик непрочитанных откликов

    for m in meetings:
        # 🆕 Считаем общее количество откликов
        count_stmt = select(func.count(MeetingResponseModel.id)).where(
            MeetingResponseModel.meeting_id == m.id
        )
        count_result = await db.execute(count_stmt)
        responses_count = count_result.scalar() or 0
        
        # 🆕 Считаем непрочитанные отклики (только pending — те, что ждут решения!)
        unread_stmt = select(func.count(MeetingResponseModel.id)).where(
            MeetingResponseModel.meeting_id == m.id,
            MeetingResponseModel.is_read == False,
            MeetingResponseModel.status == 'pending'  # 🆕 Только ожидающие решения!
        )
        unread_result = await db.execute(unread_stmt)
        unread_count = unread_result.scalar() or 0
        
        total_unread += unread_count  # 🆕 Добавляем в общую копилку
        
        response_list.append(MeetingResponse(
            id=m.id,
            user_id=m.user_id,
            creator_id=m.user_id,
            title=m.title,
            description=m.description,
            meeting_date=m.meeting_date,
            meeting_time=m.meeting_time,
            location=m.location,
            partner_wishes=m.partner_wishes,
            finance=m.finance,
            status=m.status,
            created_at=m.created_at,
            creator_username=current_user.username,
            creator_avatar_url=current_user.avatar_url,
            creator_age=calculate_age(current_user.birth_date),
            creator_gender=current_user.gender,
            responses_count=responses_count,
            unread_responses_count=unread_count,  # 🆕 Передаём количество непрочитанных для каждой встречи
            has_responded=True,
        ))
    
    # 🆕 Возвращаем обёрнутый ответ с общим количеством непрочитанных
    return MyMeetingsResponse(
        meetings=response_list,
        total_unread_responses=total_unread
    )

@router.delete("/{meeting_id}")
async def cancel_meeting(
    meeting_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Meeting).where(Meeting.id == meeting_id)
    result = await db.execute(stmt)
    meeting = result.scalar_one_or_none()
    
    if not meeting:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Встреча не найдена")
    
    if meeting.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Нельзя отменить чужую встречу")
    
    meeting.status = "cancelled"
    await db.commit()
    
    return {"message": "Встреча отменена"}