import os
import random
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException, Request, status, Form, Body
from fastapi.responses import RedirectResponse, HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from jose import jwt

from app.database import get_db
from app.models import User, VerificationRequest, Meeting, MeetingResponse as MeetingResponseModel
from app.config import SECRET_KEY, ALGORITHM, ACCESS_TOKEN_EXPIRE_MINUTES
from app.s3_client import generate_presigned_url

router = APIRouter(prefix="/admin", tags=["Админка"])

# Шаблонизатор (тот же, что в main.py)
templates = Jinja2Templates(directory="templates")


# --- Хелперы ---

def create_admin_cookie(user_id: str) -> str:
    """Создаёт JWT-токен для cookie админки."""
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode = {"sub": user_id, "exp": expire, "role": "admin"}
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


async def get_admin_user(request: Request, db: AsyncSession = Depends(get_db)) -> User | None:
    """Получает текущего админа из cookie."""
    token = request.cookies.get("admin_token")
    if not token:
        return None
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("role") != "admin":
            return None
        user_id = payload.get("sub")
        if not user_id:
            return None
        user = await db.get(User, user_id)
        if user and user.is_admin:
            return user
    except Exception:
        pass
    return None


def admin_required(func):
    """Декоратор: если не админ — редирект на логин."""
    from functools import wraps

    @wraps(func)
    async def wrapper(request: Request, *args, db: AsyncSession = Depends(get_db), **kwargs):
        user = await get_admin_user(request, db)
        if not user:
            return RedirectResponse(url="/admin/login", status_code=303)
        request.state.admin_user = user
        return await func(request, *args, db=db, **kwargs)

    return wrapper


# --- Эндпоинты логина ---

@router.get("/login", response_class=HTMLResponse)
async def login_page(request: Request, step: str = "phone", phone: str = "", error: str = ""):
    """Показывает страницу логина."""
    return templates.TemplateResponse("admin/login.html", {
        "request": request,
        "step": step,
        "phone": phone,
        "error": error,
    })


@router.post("/login/send-code")
async def admin_send_code(request: Request, phone: str = Form(...), db: AsyncSession = Depends(get_db)):
    """Отправляет SMS-код админу (использует ту же логику, что обычный auth)."""
    stmt = select(User).where(User.phone == phone)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        return RedirectResponse(url="/admin/login?error=Пользователь+не+найден", status_code=303)

    if not user.is_admin:
        return RedirectResponse(url="/admin/login?error=Нет+прав+администратора", status_code=303)

    # Генерируем код
    code = f"{random.randint(1000, 9999)}"
    user.otp_code = code
    user.otp_expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)
    user.last_code_sent_at = datetime.now(timezone.utc)
    user.failed_attempts = 0
    await db.commit()

    print(f"🔐 Админ-код для {phone}: {code}", flush=True)

    # Перенаправляем на ввод кода
    return RedirectResponse(
        url=f"/admin/login?step=code&phone={phone}",
        status_code=303
    )


@router.post("/login/verify")
async def admin_verify_code(request: Request, phone: str = Form(...), code: str = Form(...), db: AsyncSession = Depends(get_db)):
    """Проверяет код и выдаёт cookie."""
    stmt = select(User).where(User.phone == phone)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        return RedirectResponse(url="/admin/login?error=Пользователь+не+найден", status_code=303)

    if not user.is_admin:
        return RedirectResponse(url="/admin/login?error=Нет+прав+администратора", status_code=303)

    is_code_valid = (
        user.otp_code == code
        and user.otp_expires_at
        and user.otp_expires_at > datetime.now(timezone.utc)
    )

    if not is_code_valid:
        user.failed_attempts += 1
        await db.commit()
        return RedirectResponse(url=f"/admin/login?step=code&phone={phone}&error=Неверный+код", status_code=303)

    # Очищаем OTP
    user.otp_code = None
    user.otp_expires_at = None
    user.failed_attempts = 0
    await db.commit()

    # Создаём cookie
    token = create_admin_cookie(str(user.id))
    response = RedirectResponse(url="/admin/dashboard", status_code=303)
    response.set_cookie(
        key="admin_token",
        value=token,
        httponly=True,  # Не доступен из JS (безопасность)
        max_age=60 * 60 * 24 * 7,  # 7 дней
        samesite="lax",
    )
    return response


@router.post("/logout")
@admin_required
async def admin_logout(request: Request):
    """Выход из админки."""
    response = RedirectResponse(url="/admin/login", status_code=303)
    response.delete_cookie(key="admin_token")
    return response


# --- Дашборд (заглушка) ---

@router.get("/dashboard", response_class=HTMLResponse)
@admin_required
async def admin_dashboard(request: Request, db: AsyncSession = Depends(get_db)):
    """Главная страница админки."""
    return templates.TemplateResponse("admin/dashboard.html", {
        "request": request,
        "admin_user": request.state.admin_user,
    })


# --- Верификации ---

@router.get("/verifications", response_class=HTMLResponse)
@admin_required
async def verifications_page(request: Request, db: AsyncSession = Depends(get_db)):
    """Страница со списком заявок на верификацию."""
    # Получаем все pending-заявки вместе с данными пользователей
    stmt = select(VerificationRequest, User).join(
        User, VerificationRequest.user_id == User.id
    ).where(
        VerificationRequest.status == "pending"
    ).order_by(VerificationRequest.created_at.asc())

    result = await db.execute(stmt)
    requests_data = result.all()

    # Формируем список словарей для шаблона
    requests_list = []
    for req, user in requests_data:
        requests_list.append({
            "request_id": str(req.id),
            "user_id": str(user.id),
            "username": user.username or "Без имени",
            "phone": user.phone,
            "avatar_url": user.avatar_url,
            "photo_url": req.photo_url,
            "created_at": req.created_at.strftime("%d.%m.%Y %H:%M"),
        })

    return templates.TemplateResponse("admin/verifications.html", {
        "request": request,
        "requests": requests_list,
    })


@router.post("/verifications/{request_id}/approve")
@admin_required
async def approve_verification(request: Request, request_id: str, db: AsyncSession = Depends(get_db)):
    """Одобрить заявку на верификацию."""
    req = await db.get(VerificationRequest, request_id)
    if not req or req.status != "pending":
        return "<tr><td colspan='4' class='px-6 py-4 text-red-500'>Заявка не найдена</td></tr>"

    # Обновляем заявку
    req.status = "approved"
    req.reviewed_at = datetime.now(timezone.utc)
    req.reviewed_by = request.state.admin_user.id

    # Верифицируем пользователя
    user = await db.get(User, req.user_id)
    user.is_verified = True

    await db.commit()

    # HTMX заменит строку на это
    return f"""
    <tr id="row-{request_id}" class="bg-green-50">
        <td colspan="4" class="px-6 py-4 text-green-700 text-center font-medium">
            ✅ Верификация одобрена для {user.username or 'пользователя'}
        </td>
    </tr>
    """


@router.post("/verifications/{request_id}/reject")
@admin_required
async def reject_verification(
    request: Request,
    request_id: str,
    comment: str = "",
    db: AsyncSession = Depends(get_db)
):
    """Отклонить заявку на верификацию."""
    req = await db.get(VerificationRequest, request_id)
    if not req or req.status != "pending":
        return "<tr><td colspan='4' class='px-6 py-4 text-red-500'>Заявка не найдена</td></tr>"

    # Обновляем заявку
    req.status = "rejected"
    req.reviewed_at = datetime.now(timezone.utc)
    req.reviewed_by = request.state.admin_user.id
    req.admin_comment = comment if comment else None

    await db.commit()

    user = await db.get(User, req.user_id)

    # HTMX заменит строку на это
    return f"""
    <tr id="row-{request_id}" class="bg-red-50">
        <td colspan="4" class="px-6 py-4 text-red-700 text-center font-medium">
            ❌ Заявка отклонена{f': {comment}' if comment else ''}
        </td>
    </tr>
    """


# --- Встречи ---

@router.get("/meetings", response_class=HTMLResponse)
@admin_required
async def meetings_page(request: Request, status_filter: str = "all", db: AsyncSession = Depends(get_db)):
    """Страница со списком всех встреч."""
    # Базовый запрос: все встречи + данные создателя
    stmt = select(Meeting, User).join(User, Meeting.user_id == User.id)

    # Фильтр по статусу
    if status_filter != "all":
        stmt = stmt.where(Meeting.status == status_filter)

    stmt = stmt.order_by(Meeting.created_at.desc())

    result = await db.execute(stmt)
    meetings_data = result.all()

    meetings_list = []
    for meeting, user in meetings_data:
        # Считаем отклики
        from sqlalchemy import func
        count_stmt = select(func.count(MeetingResponseModel.id)).where(
            MeetingResponseModel.meeting_id == meeting.id
        )
        count_result = await db.execute(count_stmt)
        responses_count = count_result.scalar() or 0

        meetings_list.append({
            "id": str(meeting.id),
            "title": meeting.title,
            "location": meeting.location,
            "meeting_date": meeting.meeting_date.strftime("%d.%m.%Y") if meeting.meeting_date else "—",
            "meeting_time": meeting.meeting_time or "",
            "status": meeting.status,
            "creator_username": user.username or "Без имени",
            "creator_phone": user.phone,
            "creator_avatar": user.avatar_url,
            "responses_count": responses_count,
        })

    return templates.TemplateResponse("admin/meetings.html", {
        "request": request,
        "meetings": meetings_list,
        "status_filter": status_filter,
    })


@router.post("/meetings/{meeting_id}/cancel")
@admin_required
async def cancel_meeting(request: Request, meeting_id: str, db: AsyncSession = Depends(get_db)):
    """Отменить встречу (админ)."""
    meeting = await db.get(Meeting, meeting_id)
    if not meeting:
        return "<tr><td colspan='6' class='px-6 py-4 text-red-500'>Встреча не найдена</td></tr>"

    meeting.status = "cancelled"
    await db.commit()

    return f"""
    <tr id="meeting-{meeting_id}" class="bg-red-50">
        <td colspan="6" class="px-6 py-4 text-red-700 text-center font-medium">
            ❌ Встреча «{meeting.title}» отменена
        </td>
    </tr>
    """


# --- Пользователи ---

@router.get("/users", response_class=HTMLResponse)
@admin_required
async def users_page(request: Request, search: str = "", db: AsyncSession = Depends(get_db)):
    """Страница со списком всех пользователей."""
    from sqlalchemy import func

    stmt = select(User)

    # Поиск по имени или телефону
    if search:
        stmt = stmt.where(
            User.username.ilike(f"%{search}%") | User.phone.ilike(f"%{search}%")
        )

    stmt = stmt.order_by(User.created_at.desc())

    result = await db.execute(stmt)
    users = result.scalars().all()

    users_list = []
    for user in users:
        # Считаем встречи
        count_stmt = select(func.count(Meeting.id)).where(Meeting.user_id == user.id)
        count_result = await db.execute(count_stmt)
        meetings_count = count_result.scalar() or 0

        users_list.append({
            "id": str(user.id),
            "username": user.username,
            "phone": user.phone,
            "avatar_url": user.avatar_url,
            "city": user.city,
            "is_verified": user.is_verified,
            "is_admin": user.is_admin,
            "is_blocked": user.is_blocked,
            "meetings_count": meetings_count,
            "created_at": user.created_at.strftime("%d.%m.%Y") if user.created_at else "—",
        })

    return templates.TemplateResponse("admin/users.html", {
        "request": request,
        "users": users_list,
        "search": search,
        "admin_id": str(request.state.admin_user.id),
    })


@router.post("/users/{user_id}/block")
@admin_required
async def block_user(request: Request, user_id: str, db: AsyncSession = Depends(get_db)):
    """Заблокировать пользователя."""
    user = await db.get(User, user_id)
    if not user or user.is_admin:
        return "<tr><td colspan='8' class='px-6 py-4 text-red-500'>Пользователь не найден или админ</td></tr>"

    user.is_blocked = True
    await db.commit()

    return f"""
    <tr id="user-{user_id}" class="bg-red-50">
        <td colspan="8" class="px-6 py-4 text-red-700 text-center font-medium">
            🚫 {user.username or 'Пользователь'} заблокирован
        </td>
    </tr>
    """


@router.post("/users/{user_id}/unblock")
@admin_required
async def unblock_user(request: Request, user_id: str, db: AsyncSession = Depends(get_db)):
    """Разблокировать пользователя."""
    user = await db.get(User, user_id)
    if not user:
        return "<tr><td colspan='8' class='px-6 py-4 text-red-500'>Пользователь не найден</td></tr>"

    user.is_blocked = False
    await db.commit()

    return f"""
    <tr id="user-{user_id}" class="hover:bg-gray-50">
        <td colspan="8" class="px-6 py-4 text-green-700 text-center font-medium">
            ✅ {user.username or 'Пользователь'} разблокирован
        </td>
    </tr>
    """


@router.delete("/users/{user_id}")
@admin_required
async def delete_user(request: Request, user_id: str, db: AsyncSession = Depends(get_db)):
    """Удалить аккаунт пользователя (админ)."""
    user = await db.get(User, user_id)
    if not user or user.is_admin:
        return "<tr><td colspan='8' class='px-6 py-4 text-red-500'>Нельзя удалить админа</td></tr>"

    # Анонимизируем (как при self-delete)
    user.username = "Удалён админом"
    user.bio = None
    user.avatar_url = None
    user.birth_date = None
    user.gender = None
    user.city = None
    user.is_verified = False
    user.is_blocked = True
    await db.commit()

    return f"""
    <tr id="user-{user_id}" class="bg-red-50">
        <td colspan="8" class="px-6 py-4 text-red-700 text-center font-medium">
            🗑️ Аккаунт удалён
        </td>
    </tr>
    """


@router.post("/users/{user_id}/toggle-premium")
@admin_required
async def toggle_premium(request: Request, user_id: str, db: AsyncSession = Depends(get_db)):
    """Выдать или забрать премиум."""
    user = await db.get(User, user_id)
    if not user:
        return "<tr><td colspan='8' class='px-6 py-4 text-red-500'>Пользователь не найден</td></tr>"

    user.is_premium = not user.is_premium
    await db.commit()

    action = "выдан" if user.is_premium else "забран"
    emoji = "👑" if user.is_premium else ""

    return f"""
    <tr id="user-{user_id}" class="hover:bg-gray-50 {{"bg-red-50" if user.is_blocked else ""}}">
        <td colspan="8" class="px-6 py-4 text-center font-medium">
            {emoji} Премиум {action} для {user.username or 'пользователя'}
        </td>
    </tr>
    """


@router.post("/users/{user_id}/toggle-admin")
@admin_required
async def toggle_admin(request: Request, user_id: str, db: AsyncSession = Depends(get_db)):
    """Выдать или забрать права админа."""
    user = await db.get(User, user_id)
    if not user:
        return "<tr><td colspan='8' class='px-6 py-4 text-red-500'>Пользователь не найден</td></tr>"

    # Нельзя снять админа у самого себя
    if user.id == request.state.admin_user.id:
        return "<tr><td colspan='8' class='px-6 py-4 text-red-500'>Нельзя снять права у себя</td></tr>"

    user.is_admin = not user.is_admin
    await db.commit()

    action = "выданы" if user.is_admin else "забраны"

    return f"""
    <tr id="user-{user_id}" class="hover:bg-gray-50">
        <td colspan="8" class="px-6 py-4 text-center font-medium">
            🔐 Права админа {action} для {user.username or 'пользователя'}
        </td>
    </tr>
    """


# --- Presigned URL для фото в админке ---

@router.post("/photos/presigned")
@admin_required
async def get_admin_presigned_url(
    request: Request,
    key: str = Form(...),
    size: str = Form("large"),
    db: AsyncSession = Depends(get_db)
):
    """Получить presigned URL для фото (админка)"""
    from fastapi.responses import HTMLResponse
    from markupsafe import Markup

    presigned_url = await generate_presigned_url(key)
    safe_url = Markup(presigned_url)

    # Если маленькое (аватарка) — возвращаем img
    if size == "small":
        html = f'<img src="{safe_url}" alt="Аватар" class="h-10 w-10 rounded-full object-cover">'
        return HTMLResponse(content=html)

    # Иначе — модалка
    html = f'''
    <script>
        const old = document.getElementById('photo-modal');
        if (old) old.remove();
    </script>
    <div id="photo-modal" class="fixed inset-0 bg-black/80 flex items-center justify-center z-50" onclick="this.style.display='none'">
        <div class="max-w-4xl max-h-[90vh] p-4" onclick="event.stopPropagation()">
            <img src="{safe_url}" alt="Фото" class="max-w-full max-h-[85vh] object-contain rounded-lg shadow-2xl">
            <div class="flex justify-center mt-4 space-x-4">
                <a href="{safe_url}" target="_blank" class="bg-purple-600 hover:bg-purple-700 text-white px-6 py-2 rounded-lg transition">
                    Открыть в новом окне
                </a>
                <button onclick="document.getElementById('photo-modal').style.display='none'" class="bg-gray-600 hover:bg-gray-700 text-white px-6 py-2 rounded-lg transition">
                    Закрыть
                </button>
            </div>
        </div>
    </div>
    '''
    return HTMLResponse(content=html)
