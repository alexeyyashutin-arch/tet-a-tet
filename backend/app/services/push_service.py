import firebase_admin
from firebase_admin import messaging, credentials
import os

# Инициализируем Firebase Admin SDK
def initialize_firebase():
    if not firebase_admin._apps:
        # Путь к нашему ключу
        cred_path = os.path.join(os.path.dirname(__file__), '../../firebase/serviceAccountKey.json')
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)

# Убедимся, что Firebase инициализирован
initialize_firebase()

async def send_push_notification(fcm_token: str, title: str, body: str):
    """Отправляет Push-уведомление через Firebase Cloud Messaging API V1"""
    if not fcm_token:
        print("⚠️ FCM токен не найден")
        return False

    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        data={
            "click_action": "FLUTTER_NOTIFICATION_CLICK"
        },
        token=fcm_token,
    )

    try:
        response = messaging.send(message)
        print(f"✅ Уведомление отправлено: {response}")
        return True
    except Exception as e:
        print(f"❌ Ошибка отправки уведомления: {e}")
        return False