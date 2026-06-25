"""
Тесты для JWT-утилит 🦊

Эти тесты проверяют, что функции создания и проверки токенов работают правильно.
"""

import pytest
from datetime import timedelta
from app.jwt_utils import create_access_token, verify_token


class TestCreateAccessToken:
    """Тесты для функции create_access_token"""

    def test_creates_valid_token(self):
        """Проверяем, что функция создаёт токен (не пустую строку)"""
        data = {"sub": "user-123"}
        token = create_access_token(data)
        
        # Токен — это не пустая строка
        assert token is not None
        assert len(token) > 0
        
    def test_token_contains_original_data(self):
        """Проверяем, что данные из токена можно извлечь"""
        user_id = "test-user-456"
        data = {"sub": user_id}
        
        # Создаём токен
        token = create_access_token(data)
        
        # Извлекаем данные обратно
        payload = verify_token(token)
        
        # Проверяем, что пользовательский ID совпадает
        assert payload is not None
        assert payload["sub"] == user_id
        
    def test_token_has_expiration_time(self):
        """Проверяем, что в токене есть время истечения"""
        data = {"sub": "user-789"}
        token = create_access_token(data)
        
        payload = verify_token(token)
        
        # В полезной нагрузке должно быть поле "exp" (время истечения)
        assert "exp" in payload
        
    def test_custom_expiration_time(self):
        """Проверяем, что можно задать своё время жизни токена"""
        data = {"sub": "user-custom"}
        custom_expiry = timedelta(minutes=30)
        
        token = create_access_token(data, expires_delta=custom_expiry)
        payload = verify_token(token)
        
        # Токен должен быть валидным
        assert payload is not None
        assert "exp" in payload


class TestVerifyToken:
    """Тесты для функции verify_token"""

    def test_valid_token_returns_payload(self):
        """Валидный токен возвращает словарь с данными"""
        data = {"sub": "verified-user", "role": "admin"}
        token = create_access_token(data)
        
        payload = verify_token(token)
        
        assert payload is not None
        assert payload["sub"] == "verified-user"
        assert payload["role"] == "admin"
        
    def test_invalid_token_returns_none(self):
        """Невалидный (поддельный) токен возвращает None"""
        fake_token = "this.is.not.a.real.token"
        
        result = verify_token(fake_token)
        
        # Функция должна вернуть None для мусорного токена
        assert result is None
        
    def test_tampered_token_returns_none(self):
        """Подделанный токен возвращает None"""
        data = {"sub": "hacker"}
        token = create_access_token(data)
        
        # Подменяем токен (меняем последний символ)
        tampered_token = token[:-1] + ("0" if token[-1] != "0" else "1")
        
        result = verify_token(tampered_token)
        
        # Должно вернуть None, потому что подпись не совпадёт
        assert result is None


class TestTokenDataIntegrity:
    """Тесты на целостность данных в токене"""

    def test_multiple_fields_preserved(self):
        """Все поля из словаря сохраняются в токене"""
        data = {
            "sub": "user-123",
            "email": "test@example.com",
            "is_premium": True,
            "age": 25
        }
        
        token = create_access_token(data)
        payload = verify_token(token)
        
        # Проверяем каждое поле
        assert payload["sub"] == "user-123"
        assert payload["email"] == "test@example.com"
        assert payload["is_premium"] is True
        assert payload["age"] == 25
        
    def test_empty_data_creates_token_with_only_exp(self):
        """Даже пустой словарь создаёт токен (с полем exp)"""
        data = {}
        token = create_access_token(data)
        
        payload = verify_token(token)
        
        # Токен создан и содержит время истечения
        assert payload is not None
        assert "exp" in payload