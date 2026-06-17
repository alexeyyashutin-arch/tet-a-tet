import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final ApiService _api = ApiService();

  Future<void> initialize() async {
    // 1. Запрашиваем разрешение
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Пользователь разрешил уведомления');
      
      // 2. Получаем токен
      String? token = await _fcm.getToken();
      if (token != null) {
        print('🔑 FCM Token получен: $token');
        await _api.updateFcmToken(token);
      }
    } else {
      print('❌ Пользователь отклонил уведомления');
    }

    // 🆕 3. Слушаем клики по уведомлениям (когда приложение в фоне)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationClick);
    
    // 🆕 4. Проверяем, не было ли открытия приложения через уведомление
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationClick(initialMessage);
    }
  }

  // 🆕 Обработчик клика по уведомлению
  void _handleNotificationClick(RemoteMessage message) {
    print('🔔 Клик по уведомлению: ${message.data}');
    
    final type = message.data['type'];
    final meetingId = message.data['meeting_id'];
    
    if (meetingId != null) {
      // 🆕 Сохраняем данные для навигации (обработаем в main_screen.dart)
      _pendingNavigation = {
        'type': type,
        'meeting_id': meetingId,
      };
      
      // 🆕 Уведомляем MainScreen о необходимости навигации
      if (_onNavigationCallback != null) {
        _onNavigationCallback!(_pendingNavigation!);
      }
    }
  }

  // 🆕 Хранилище для отложенной навигации
  static Map<String, dynamic>? _pendingNavigation;
  static Function(Map<String, dynamic>)? _onNavigationCallback;

  // 🆕 Метод для регистрации callback'а навигации
  static void onNavigation(Function(Map<String, dynamic>) callback) {
    _onNavigationCallback = callback;
  }

  // 🆕 Получить отложенную навигацию
  static Map<String, dynamic>? getPendingNavigation() {
    return _pendingNavigation;
  }

  // 🆕 Очистить отложенную навигацию
  static void clearPendingNavigation() {
    _pendingNavigation = null;
  }
}