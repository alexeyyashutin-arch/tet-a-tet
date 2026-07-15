"""
WebSocket-роутер для чата в реальном времени.

Как это работает (для Лёши):
1. Клиент (Flutter-приложение) подключается к /ws/{meeting_id}?token=...
2. Мы проверяем JWT-токен — тот же самый, что используется для HTTP-запросов
3. Если токен валидный — подключаем пользователя к «комнате» этой встречи
4. Когда кто-то пишет сообщение — сохраняем в БД и рассылаем всем в комнате
"""

import os
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sqlalchemy import select

from ..config import SECRET_KEY, ALGORITHM
from ..database import AsyncSessionLocal
from ..models import Message, User
from ..jwt_utils import verify_token
from ..websocket_manager import manager

router = APIRouter()


@router.websocket("/ws/{meeting_id}")
async def websocket_endpoint(websocket: WebSocket, meeting_id: str, token: str):
    """
    WebSocket-эндпоинт для чата внутри встречи.

    Параметры:
    - meeting_id: UUID встречи (берётся из URL)
    - token: JWT-токен (передаётся как query-параметр: ?token=...)

    Почему токен в URL, а не в заголовке?
    Потому что WebSocket-протокол не поддерживает кастомные заголовки
    при первом подключении — только URL. Поэтому токен передаём в строке запроса.
    """

    # --- Шаг 1: Проверяем JWT-токен ---
    # Используем ту же функцию verify_token, что и для HTTP-запросов.
    # Это значит, что секретный ключ и алгоритм — единые для всего приложения.
    payload = verify_token(token)
    if payload is None:
        # Если токен невалидный — закрываем соединение с кодом 4001
        # (кастомный код, чтобы фронт мог понять причину)
        await websocket.close(code=4001, reason="Недействительный токен")
        return

    user_id_str = payload.get("sub")
    if user_id_str is None:
        await websocket.close(code=4001, reason="Токен не содержит ID пользователя")
        return

    # --- Шаг 2: Подключаем пользователя к комнате чата ---
    # manager — это экземпляр ConnectionManager из websocket_manager.py
    # Он хранит все активные WebSocket-соединения, сгруппированные по meeting_id
    await manager.connect(websocket, meeting_id)

    try:
        # --- Шаг 3: Бесконечный цикл ожидания сообщений ---
        # WebSocket остаётся открытым, пока клиент не отключится.
        # Каждое новое сообщение от клиента обрабатывается здесь.
        while True:
            data = await websocket.receive_json()

            if data.get("type") == "message":
                text = data.get("text", "").strip()
                if not text:
                    continue  # Игнорируем пустые сообщения

                # --- Шаг 4: Сохраняем сообщение в БД ---
                # Используем AsyncSessionLocal (фабрику сессий) вместо прямого engine
                # Это правильный подход: сессия создаётся и закрывается для каждой операции
                async with AsyncSessionLocal() as db:
                    new_message = Message(
                        meeting_id=meeting_id,
                        sender_id=user_id_str,
                        text=text,
                        is_read=False,
                    )
                    db.add(new_message)
                    await db.commit()
                    await db.refresh(new_message)

                    # Получаем данные отправителя для красивого отображения в чате
                    user = await db.get(User, user_id_str)
                    sender_name = user.username if user else "Аноним"
                    sender_avatar = user.avatar_url if user else None

                # --- Шаг 5: Рассылаем сообщение всем в комнате ---
                # broadcast отправляет JSON всем подключённым пользователям
                # (включая отправителя — так фронт понимает, что сообщение доставлено)
                await manager.broadcast(
                    meeting_id,
                    {
                        "type": "new_message",
                        "id": str(new_message.id),
                        "text": text,
                        "sender_id": user_id_str,
                        "sender_username": sender_name,
                        "sender_avatar_url": sender_avatar,
                        "created_at": new_message.created_at.isoformat(),
                    },
                )

    except WebSocketDisconnect:
        # Клиент отключился (закрыл приложение, пропал интернет и т.д.)
        # Убираем его из списка активных соединений
        manager.disconnect(websocket, meeting_id)
    except Exception as e:
        # На всякий случай: если что-то пошло не так — отключаем
        print(f"❌ Ошибка WebSocket в комнате {meeting_id}: {e}", flush=True)
        manager.disconnect(websocket, meeting_id)