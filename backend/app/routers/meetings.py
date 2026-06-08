import uuid
from datetime import date
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List

from ..database import get_db
from ..models import User, Meeting
from ..schemas import MeetingCreate, MeetingResponse
from ..dependencies import get_current_user

router = APIRouter(prefix="/meetings", tags=["Встречи"])

# 🆕 Вспомогательная функция для вычисления возраста
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
    # Проверяем, что дата не в прошлом
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
    
    # Возвращаем с информацией о создателе
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
        creator_age=calculate_age(current_user.birth_date) 
    )

@router.get("/", response_model=List[MeetingResponse])
async def get_active_meetings(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Получаем все активные встречи, кроме наших
    stmt = select(Meeting, User).join(User, Meeting.user_id == User.id).where(
        Meeting.status == "active",
        Meeting.user_id != current_user.id
    ).order_by(Meeting.meeting_date.asc(), Meeting.meeting_time.asc())
    
    result = await db.execute(stmt)
    meetings_data = result.all()
    
    meetings = []
    for meeting, user in meetings_data:
        meetings.append(MeetingResponse(
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
            creator_username=user.username,
            creator_avatar_url=user.avatar_url,
            creator_age=calculate_age(current_user.birth_date) 
        ))
    
    return meetings

@router.get("/my", response_model=List[MeetingResponse])
async def get_my_meetings(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Meeting).where(Meeting.user_id == current_user.id).order_by(
        Meeting.meeting_date.asc()
    )
    
    result = await db.execute(stmt)
    meetings = result.scalars().all()
    
    return [
        MeetingResponse(
            id=m.id,
            user_id=m.user_id,
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
            creator_age=calculate_age(current_user.birth_date) 
        )
        for m in meetings
    ]

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