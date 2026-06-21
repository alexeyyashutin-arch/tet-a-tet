import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// 🆕 Сервис для хранения локальных настроек приложения
class SettingsService {
  static const String _keyPushEnabled = 'push_enabled';
  static const String _keySoundEnabled = 'sound_enabled';
  static const String _keyResponsesNotify = 'notify_responses';
  static const String _keyMessagesNotify = 'notify_messages';
  static const String _keyLanguage = 'language'; // 'ru' или 'en'

  // 🔔 Уведомления
  static Future<bool> isPushEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPushEnabled) ?? true; // По умолчанию включено
  }

  static Future<void> setPushEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPushEnabled, value);
  }

  static Future<bool> isSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySoundEnabled) ?? true;
  }

  static Future<void> setSoundEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySoundEnabled, value);
  }

  static Future<bool> isResponsesNotifyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyResponsesNotify) ?? true;
  }

  static Future<void> setResponsesNotifyEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyResponsesNotify, value);
    
    // 🆕 Отправляем на backend
    await ApiService().updateNotificationSettings(notifyResponses: value);
  }

  static Future<bool> isMessagesNotifyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyMessagesNotify) ?? true;
  }

  static Future<void> setMessagesNotifyEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMessagesNotify, value);
    
    // 🆕 Отправляем на backend
    await ApiService().updateNotificationSettings(notifyMessages: value);
  }

  // 🎨 Внешний вид
  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguage) ?? 'ru';
  }

  static Future<void> setLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, value);
  }

  // 🆕 Тема приложения
  static const String _keyTheme = 'app_theme'; // 'basic' или 'premium'

  static Future<String> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTheme) ?? 'basic';
  }

  static Future<void> setTheme(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, value);
  }
}