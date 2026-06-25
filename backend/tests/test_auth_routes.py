"""
Тесты для роутов аутентификации 🦊

Эти тесты проверяют корректность работы эндпоинтов аутентификации:
- Отправка SMS-кода
- Проверка SMS-кода и получение токена
"""

import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.jwt_utils import verify_token
from uuid import UUID
from datetime import datetime, timedelta
import re


class TestAuthRoutes:
    """Тесты для роутов аутентификации"""

    def test_send_code_new_user(self):
        """Тест отправки кода для нового пользователя"""
        with TestClient(app) as client:
            phone_number = "+79991234567"
            
            response = client.post("/auth/send-code", json={"phone": phone_number})
            
            assert response.status_code == 200
            assert response.json() == {"message": "Код отправлен. Проверьте SMS."}

    def test_send_code_existing_user(self):
        """Тест отправки кода для существующего пользователя"""
        with TestClient(app) as client:
            phone_number = "+79991234567"
            
            # Первый запрос создаст пользователя
            response = client.post("/auth/send-code", json={"phone": phone_number})
            assert response.status_code == 200
            
            # Второй запрос для существующего пользователя
            response = client.post("/auth/send-code", json={"phone": phone_number})
            assert response.status_code == 200
            assert response.json() == {"message": "Код отправлен. Проверьте SMS."}

    def test_send_code_rate_limit(self):
        """Тест ограничения частоты отправки кода"""
        with TestClient(app) as client:
            phone_number = "+79991234567"
            
            # Отправляем первый код
            response = client.post("/auth/send-code", json={"phone": phone_number})
            assert response.status_code == 200
            
            # Отправляем второй код сразу после первого
            response = client.post("/auth/send-code", json={"phone": phone_number})
            
            # Ожидаем ошибку ограничения частоты
            assert response.status_code == 429
            response_data = response.json()
            assert "wait" in response_data["detail"].lower() or "ожидайте" in response_data["detail"].lower()

    def test_verify_code_invalid_code(self):
        """Тест проверки неверного кода"""
        with TestClient(app) as client:
            phone_number = "+79991234567"
            
            # Отправляем код
            response = client.post("/auth/send-code", json={"phone": phone_number})
            assert response.status_code == 200
            
            # Проверяем неверный код
            response = client.post("/auth/verify-code", json={
                "phone": phone_number,
                "code": "0000"  # Неверный код
            })
            
            assert response.status_code == 400
            assert "неверный" in response.json()["detail"].lower() or "неправильный" in response.json()["detail"].lower()

    def test_verify_code_user_not_found(self):
        """Тест проверки кода для несуществующего пользователя"""
        with TestClient(app) as client:
            response = client.post("/auth/verify-code", json={
                "phone": "+79991234567",
                "code": "1234"
            })
            
            assert response.status_code == 404
            assert "пользователь" in response.json()["detail"].lower()

    def test_phone_validation_format(self):
        """Тест валидации формата номера телефона"""
        with TestClient(app) as client:
            invalid_numbers = [
                "123",  # Слишком короткий
                "abcdefghij",  # Не цифры
                "+799912345678901234567890",  # Слишком длинный
                "",  # Пустой
                "89991234567"  # Неправильный формат
            ]
            
            for phone in invalid_numbers:
                response = client.post("/auth/send-code", json={"phone": phone})
                assert response.status_code == 422, f"Failed for phone: {phone}"

    def test_phone_normalization(self):
        """Тест нормализации номера телефона"""
        with TestClient(app) as client:
            phone_variants = [
                "+7 (999) 123-45-67",
                "8 (999) 123-45-67",
                "79991234567",
                "+7-999-123-45-67",
                "(799)999-12-34-567"
            ]
            
            for phone in phone_variants:
                response = client.post("/auth/send-code", json={"phone": phone})
                
                # Проверяем, что запрос проходит успешно (формат валиден)
                # или что возвращается ошибка не связанная с форматом
                assert response.status_code in [200, 429]  # 429 - ограничение по частоте

    def test_bruteforce_protection(self):
        """Тест защиты от брутфорса при проверке кода"""
        with TestClient(app) as client:
            phone_number = "+79991234567"
            
            # Сначала отправляем код
            response = client.post("/auth/send-code", json={"phone": phone_number})
            assert response.status_code == 200
            
            # Делаем несколько попыток с неверным кодом
            for _ in range(5):
                response = client.post("/auth/verify-code", json={
                    "phone": phone_number,
                    "code": "0000"  # Неверный код
                })
                if response.status_code == 400:  # Ожидаем ошибку неверного кода
                    continue
                elif response.status_code == 429:  # Или ошибку ограничения
                    break
            
            # Следующая попытка должна вызвать ошибку блокировки
            response = client.post("/auth/verify-code", json={
                "phone": phone_number,
                "code": "0000"
            })
            
            assert response.status_code == 429
            assert "слишком" in response.json()["detail"].lower() or "много" in response.json()["detail"].lower()
