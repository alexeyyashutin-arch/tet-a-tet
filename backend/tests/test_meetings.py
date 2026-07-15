"""
Тесты для роутов встреч (meetings) 🦊

Проверяем:
- Создание, получение, отмену встреч
- Обработку ошибок (неавторизованный доступ, чужая встреча, невалидные данные)
- Фильтрацию и поиск

Как работают фикстуры:
1. conftest.py создаёт in-memory SQLite базу для тестов (быстро и изолированно)
2. async_client — HTTP-клиент, который ходит в наше FastAPI-приложение
3. auth_headers — создаёт тестового пользователя и возвращает заголовки с токеном
   (имитирует то, что делает Flutter-приложение после входа по SMS)
"""

import pytest
from datetime import date, timedelta
from app.models import User, Meeting
from app.jwt_utils import create_access_token


# ============================================================
# 🔧 ФИКСТУРЫ — вспомогательные штуки для тестов
# ============================================================

@pytest.fixture
async def auth_headers(test_session):
    """
    Создаёт тестового пользователя в БД и возвращает HTTP-заголовки
    с JWT-токеном. Этот токен приложение проверяет через get_current_user().
    
    По сути, мы «притворяемся» авторизованным пользователем без
    настоящего SMS-кода — просто сразу кладём юзера в БД и генерируем токен.
    """
    user = User(
        phone="+79991234567",
        username="ТестовыйЛёша",
        gender="male",
        birth_date=date(1995, 5, 15),
        city="Москва",
        is_verified=True,
    )
    test_session.add(user)
    await test_session.commit()
    await test_session.refresh(user)

    # Генерируем JWT-токен — точно такой же, какой выдал бы /auth/verify-code
    token = create_access_token(data={"sub": str(user.id)})

    return {
        "Authorization": f"Bearer {token}",
        "X-User-Id": str(user.id),  # пригодится в тестах
    }


@pytest.fixture
async def second_user(test_session):
    """
    Второй пользователь — нужен для тестов, где один юзер пытается
    отменить встречу другого (проверка защиты от «угона» встречи).
    """
    user = User(
        phone="+79997654321",
        username="ДругойПользователь",
        gender="female",
        birth_date=date(1998, 8, 20),
        city="Москва",
        is_verified=True,
    )
    test_session.add(user)
    await test_session.commit()
    await test_session.refresh(user)

    token = create_access_token(data={"sub": str(user.id)})
    return {
        "Authorization": f"Bearer {token}",
        "X-User-Id": str(user.id),
    }


# ============================================================
# 📝 ТЕСТЫ: СОЗДАНИЕ ВСТРЕЧИ (POST /meetings/)
# ============================================================

class TestCreateMeeting:
    """Тесты на создание встречи — самая важная фича приложения!"""

    async def test_create_meeting_success(self, async_client, auth_headers):
        """
        ✅ Успешное создание встречи со всеми полями.
        
        Проверяем:
        - Статус 201 (Created)
        - Все поля вернулись корректно
        - Статус встречи "active" (по умолчанию)
        """
        meeting_data = {
            "title": "Ужин в ресторане при свечах",
            "description": "Хочу пригласить прекрасную даму в итальянский ресторан",
            "meeting_date": str(date.today() + timedelta(days=3)),
            "meeting_time": "19:00",
            "location": "Ресторан 'Марио', ул. Тверская 15",
            "partner_wishes": "Желательно без вредных привычек, любительница итальянской кухни",
            "finance": "self",
        }

        response = await async_client.post(
            "/meetings/", json=meeting_data, headers=auth_headers
        )

        assert response.status_code == 201, f"Ожидался 201, получили {response.status_code}: {response.text}"
        
        data = response.json()
        assert data["title"] == meeting_data["title"]
        assert data["description"] == meeting_data["description"]
        assert data["status"] == "active"
        assert data["finance"] == "self"
        assert data["creator_username"] == "ТестовыйЛёша"
        assert "id" in data  # UUID встречи

    async def test_create_meeting_unauthorized(self, async_client):
        """
        ❌ Попытка создать встречу без авторизации.
        
        FastAPI должен вернуть 401 (Unauthorized), потому что
        эндпоинт зависит от get_current_user, а токена нет.
        """
        meeting_data = {
            "title": "Ужин в ресторане",
            "meeting_date": str(date.today() + timedelta(days=1)),
            "finance": "self",
        }

        response = await async_client.post("/meetings/", json=meeting_data)
        assert response.status_code in [401, 403], f"Ожидался 401/403, получили {response.status_code}"

    async def test_create_meeting_past_date(self, async_client, auth_headers):
        """
        ❌ Попытка создать встречу с датой в прошлом.
        
        Бизнес-логика: нельзя создать встречу на вчера или более раннюю дату.
        Сервер должен вернуть 400 (Bad Request).
        """
        meeting_data = {
            "title": "Вчерашняя прогулка",
            "meeting_date": str(date.today() - timedelta(days=1)),
            "finance": "self",
        }

        response = await async_client.post(
            "/meetings/", json=meeting_data, headers=auth_headers
        )

        assert response.status_code == 400
        assert "прошлом" in response.json()["detail"].lower()

    async def test_create_meeting_short_title(self, async_client, auth_headers):
        """
        ❌ Попытка создать встречу со слишком коротким заголовком.
        
        Pydantic-схема требует title длиной минимум 5 символов.
        FastAPI автоматически валидирует и возвращает 422 (Validation Error).
        """
        meeting_data = {
            "title": "Уж",  # всего 2 символа, а нужно минимум 5
            "meeting_date": str(date.today() + timedelta(days=1)),
            "finance": "self",
        }

        response = await async_client.post(
            "/meetings/", json=meeting_data, headers=auth_headers
        )

        assert response.status_code == 422


# ============================================================
# 📖 ТЕСТЫ: ПОЛУЧЕНИЕ ЛЕНТЫ ВСТРЕЧ (GET /meetings/)
# ============================================================

class TestGetMeetings:
    """Тесты на получение ленты встреч с фильтрацией."""

    async def test_get_meetings_empty(self, async_client, auth_headers):
        """
        ✅ Получение пустой ленты встреч.
        
        Если никто ещё не создал встречи — должен вернуться пустой список.
        """
        response = await async_client.get("/meetings/", headers=auth_headers)

        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) == 0  # Пока встреч нет

    async def test_get_meetings_with_data(self, async_client, auth_headers):
        """
        ✅ Получение ленты с одной созданной встречей.
        
        Создаём встречу, потом запрашиваем ленту — должны её увидеть.
        """
        # Сначала создаём встречу
        meeting_data = {
            "title": "Поход в кино на новый фильм",
            "meeting_date": str(date.today() + timedelta(days=5)),
            "meeting_time": "20:00",
            "location": "Кинотеатр 'Октябрь'",
            "finance": "split",
        }
        create_resp = await async_client.post(
            "/meetings/", json=meeting_data, headers=auth_headers
        )
        assert create_resp.status_code == 201

        # Теперь получаем ленту
        response = await async_client.get("/meetings/", headers=auth_headers)

        assert response.status_code == 200
        data = response.json()
        assert len(data) == 1
        assert data[0]["title"] == meeting_data["title"]
        assert data[0]["location"] == meeting_data["location"]
        assert data[0]["status"] == "active"

    async def test_get_meetings_gender_filter(self, async_client, auth_headers, second_user):
        """
        ✅ Фильтрация встреч по полу.
        
        Создаём встречу от мужчины, фильтруем по female — встречи не должны быть видны.
        Создаём встречу от женщины, фильтруем по female — должны увидеть.
        """
        # Создаём встречу от мужчины (ТестовыйЛёша)
        await async_client.post(
            "/meetings/",
            json={
                "title": "Мужская встреча",
                "meeting_date": str(date.today() + timedelta(days=2)),
                "finance": "self",
            },
            headers=auth_headers,
        )

        # Создаём встречу от женщины (второй пользователь)
        await async_client.post(
            "/meetings/",
            json={
                "title": "Женская встреча",
                "meeting_date": str(date.today() + timedelta(days=3)),
                "finance": "self",
            },
            headers=second_user,
        )

        # Фильтруем: только встречи от female
        response = await async_client.get(
            "/meetings/?gender=female", headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()
        # Должна быть только встреча от второго пользователя (женщины)
        assert len(data) == 1
        assert data[0]["title"] == "Женская встреча"

    async def test_get_meetings_unauthorized(self, async_client):
        """
        ❌ Попытка получить ленту без авторизации.
        """
        response = await async_client.get("/meetings/")
        assert response.status_code in [401, 403]


# ============================================================
# 📋 ТЕСТЫ: МОИ ВСТРЕЧИ (GET /meetings/my)
# ============================================================

class TestMyMeetings:
    """Тесты на получение списка своих встреч."""

    async def test_my_meetings_empty(self, async_client, auth_headers):
        """
        ✅ Получение пустого списка своих встреч.
        """
        response = await async_client.get("/meetings/my", headers=auth_headers)

        assert response.status_code == 200
        data = response.json()
        assert data["meetings"] == []
        assert data["total_unread_responses"] == 0

    async def test_my_meetings_with_data(self, async_client, auth_headers):
        """
        ✅ Получение своих встреч после создания одной.
        
        Проверяем, что в списке моих встреч:
        - Есть созданная встреча
        - Нет чужих встреч
        - Счётчик непрочитанных откликов = 0 (пока никто не откликнулся)
        """
        # Создаём встречу
        await async_client.post(
            "/meetings/",
            json={
                "title": "Моя личная встреча",
                "meeting_date": str(date.today() + timedelta(days=7)),
                "finance": "self",
            },
            headers=auth_headers,
        )

        response = await async_client.get("/meetings/my", headers=auth_headers)

        assert response.status_code == 200
        data = response.json()
        assert len(data["meetings"]) == 1
        assert data["meetings"][0]["title"] == "Моя личная встреча"
        assert data["total_unread_responses"] == 0

    async def test_my_meetings_unauthorized(self, async_client):
        """
        ❌ Попытка получить свои встречи без авторизации.
        """
        response = await async_client.get("/meetings/my")
        assert response.status_code in [401, 403]


# ============================================================
# 🗑️ ТЕСТЫ: ОТМЕНА ВСТРЕЧИ (DELETE /meetings/{id})
# ============================================================

class TestCancelMeeting:
    """Тесты на отмену встречи."""

    async def test_cancel_own_meeting(self, async_client, auth_headers):
        """
        ✅ Успешная отмена своей встречи.
        
        Создаём встречу, отменяем — статус должен стать "cancelled".
        """
        # Создаём встречу
        create_resp = await async_client.post(
            "/meetings/",
            json={
                "title": "Встреча для отмены",
                "meeting_date": str(date.today() + timedelta(days=1)),
                "finance": "self",
            },
            headers=auth_headers,
        )
        meeting_id = create_resp.json()["id"]

        # Отменяем
        response = await async_client.delete(
            f"/meetings/{meeting_id}", headers=auth_headers
        )

        assert response.status_code == 200
        assert response.json() == {"message": "Встреча отменена"}

    async def test_cancel_other_users_meeting(
        self, async_client, auth_headers, second_user
    ):
        """
        ❌ Попытка отменить чужую встречу.
        
        Один пользователь создаёт встречу, второй пытается её отменить.
        Сервер должен вернуть 403 (Forbidden) — нельзя трогать чужое!
        """
        # Второй пользователь создаёт встречу
        create_resp = await async_client.post(
            "/meetings/",
            json={
                "title": "Чужая встреча",
                "meeting_date": str(date.today() + timedelta(days=2)),
                "finance": "self",
            },
            headers=second_user,
        )
        meeting_id = create_resp.json()["id"]

        # Первый пользователь пытается отменить чужую встречу
        response = await async_client.delete(
            f"/meetings/{meeting_id}", headers=auth_headers
        )

        assert response.status_code == 403
        assert "чужую" in response.json()["detail"].lower()

    async def test_cancel_nonexistent_meeting(self, async_client, auth_headers):
        """
        ❌ Попытка отменить несуществующую встречу.
        
        UUID с нулями никогда не будет существовать — проверяем 404.
        """
        fake_id = "00000000-0000-0000-0000-000000000000"

        response = await async_client.delete(
            f"/meetings/{fake_id}", headers=auth_headers
        )

        assert response.status_code == 404
        assert "не найдена" in response.json()["detail"].lower()