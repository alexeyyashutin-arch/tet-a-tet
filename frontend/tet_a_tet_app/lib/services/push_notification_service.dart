import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final ApiService _api = ApiService();

  Future<void> initialize() async {
    // 1. Запрашиваем разрешение (на iOS появится системное окно)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Пользователь разрешил уведомления');
      
      // 2. Получаем токен устройства
      String? token = await _fcm.getToken();
      
      if (token != null) {
        print(' FCM Token получен: $token');
        // 3. Отправляем токен на бэкенд
        await _api.updateFcmToken(token);
      }
    } else {
      print('❌ Пользователь отклонил уведомления');
    }
  }
}