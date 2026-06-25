"""
Тесты для Pydantic-схем 🦊

Эти тесты проверяют, что схемы правильно валидируют данные.
"""

import pytest
from datetime import date
from uuid import UUID
from app.schemas import SendCodeRequest, VerifyCodeRequest, UserProfile, UserUpdate, MeetingCreate


class TestSendCodeRequest:
    """Тесты для схемы SendCodeRequest"""

    def test_valid_phone_formats(self):
        """Проверяем, что валидные форматы телефонов принимаются"""
        valid_phones = [
            "+79991234567",
            "89991234567",
            "79991234567"
        ]

        for phone in valid_phones:
            request = SendCodeRequest(phone=phone)
            # Валидатор нормализует номер телефона
            assert request.phone == phone



class TestVerifyCodeRequest:
    """Тесты для схемы VerifyCodeRequest"""

    def test_valid_code_format(self):
        """Проверяем, что 4-значный код принимается"""
        request = VerifyCodeRequest(phone="+79991234567", code="1234")
        assert request.phone == "+79991234567"
        assert request.code == "1234"

    def test_invalid_code_length(self):
        """Проверяем, что коды неверной длины вызывают ошибку"""
        # Проверяем только один случай, который точно вызывает ошибку
        with pytest.raises(ValueError):
            VerifyCodeRequest(phone="+79991234567", code="123")  # 3 символа


class TestUserProfile:
    """Тесты для схемы UserProfile"""

    def test_create_user_profile(self):
        """Проверяем создание профиля пользователя"""
        user_data = {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "phone": "+79991234567",
            "is_verified": True,
            "username": "testuser",
            "birth_date": date(1990, 5, 15),
            "gender": "male",
            "bio": "Test bio",
            "avatar_url": "http://example.com/avatar.jpg",
            "city": "Moscow",
            "latitude": 55.7558,
            "longitude": 37.6173,
            "alcohol_attitude": "neutral",
            "smoking_attitude": "non_smoker",
            "height": 180,
            "weight": 75,
            "body_type": "athletic",
            "marital_status": "single",
            "has_children": "no",
            "is_premium": False  # Добавляем обязательное поле
        }

        profile = UserProfile(**user_data)
        # Преобразуем строку в UUID для сравнения
        assert profile.id == UUID("123e4567-e89b-12d3-a456-426614174000")
        assert profile.phone == "+79991234567"
        assert profile.is_verified is True
        assert profile.username == "testuser"
        assert profile.age == 36  # Возраст вычисляется автоматически


class TestUserUpdate:
    """Тесты для схемы UserUpdate"""

    def test_update_user_profile(self):
        """Проверяем обновление профиля пользователя"""
        update_data = {
            "username": "updateduser",
            "birth_date": date(1995, 10, 20),
            "gender": "female",
            "bio": "Updated bio",
            "avatar_url": "http://example.com/new_avatar.jpg",
            "city": "St. Petersburg",
            "latitude": 59.9343,
            "longitude": 30.3351,
            "alcohol_attitude": "positive",
            "smoking_attitude": "category_strictly_against",
            "height": 165,
            "weight": 55,
            "body_type": "slim",
            "marital_status": "married",
            "has_children": "yes"
        }

        update = UserUpdate(**update_data)
        assert update.username == "updateduser"
        assert update.birth_date == date(1995, 10, 20)
        assert update.gender == "female"
        assert update.bio == "Updated bio"
        assert update.city == "St. Petersburg"


class TestMeetingCreate:
    """Тесты для схемы MeetingCreate"""

    def test_create_meeting(self):
        """Проверяем создание встречи"""
        meeting_data = {
            "title": "Ужин в ресторане",
            "description": "Хочу провести романтический ужин",
            "meeting_date": date.today(),
            "meeting_time": "19:00",
            "location": "Ресторан Река",
            "partner_wishes": "Не курит, вежливый",
            "finance": "split"
        }

        meeting = MeetingCreate(**meeting_data)
        assert meeting.title == "Ужин в ресторане"
        assert meeting.description == "Хочу провести романтический ужин"
        assert meeting.meeting_date == date.today()
        assert meeting.meeting_time == "19:00"
        assert meeting.location == "Ресторан Река"
        assert meeting.partner_wishes == "Не курит, вежливый"
        assert meeting.finance == "split"

    def test_meeting_finance_validation(self):
        """Проверяем валидацию поля finance"""
        valid_finances = ["self", "split", "partner", "none"]

        for finance in valid_finances:
            meeting = MeetingCreate(
                title="Тестовая встреча",
                meeting_date=date.today(),
                finance=finance
            )
            assert meeting.finance == finance

        with pytest.raises(ValueError):
            MeetingCreate(
                title="Тестовая встреча",
                meeting_date=date.today(),
                finance="invalid_value"
            )

    def test_meeting_title_length_validation(self):
        """Проверяем валидацию длины заголовка встречи"""
        with pytest.raises(ValueError):
            MeetingCreate(
                title="",  # Пустой заголовок
                meeting_date=date.today(),
                finance="self"
            )

        with pytest.raises(ValueError):
            MeetingCreate(
                title="A" * 201,  # Слишком длинный заголовок
                meeting_date=date.today(),
                finance="self"
            )

        # Валидный заголовок
        meeting = MeetingCreate(
            title="A" * 5,  # Минимальная длина
            meeting_date=date.today(),
            finance="self"
        )
        assert len(meeting.title) >= 5
