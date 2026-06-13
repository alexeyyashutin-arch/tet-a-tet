import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://192.168.1.150:8000',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiService() {
    // 🤵 Магия интерсептора! Dio сам будет добавлять токен к каждому запросу
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  Future<String?> sendCode(String phone) async {
    try {
      final response = await _dio.post('/auth/send-code', data: {'phone': phone});
      return response.data['message'];
    } on DioException catch (e) {
      return e.response?.data['detail'] ?? 'Ошибка сети';
    }
  }

  Future<String?> verifyCode(String phone, String code) async {
    try {
      print('🔍 Отправляем запрос на: ${_dio.options.baseUrl}/auth/verify-code');
      print('📱 Телефон: $phone, Код: $code');
      
      final response = await _dio.post('/auth/verify-code', data: {
        'phone': phone,
        'code': code,
      });
      
      print('✅ Успех! Статус: ${response.statusCode}');
      
      final token = response.data['access_token'];
      await _storage.write(key: 'auth_token', value: token);
      
      return token;
    } on DioException catch (e) {
      print('❌ DioException! Статус: ${e.response?.statusCode}');
      print('❌ URL: ${e.requestOptions.uri}');
      print('❌ Детали: ${e.response?.data}');
      
      return e.response?.data['detail'] ?? 'Неверный код';
    } catch (e, stackTrace) {
      // 🆕 Ловим ВСЕ остальные ошибки!
      print('❌ Неизвестная ошибка: $e');
      print('❌ Stack trace: $stackTrace');
      return 'Ошибка приложения';
    }
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  // 🆕 Новый метод для получения профиля
  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final response = await _dio.get('/users/me');
      return response.data;
    } on DioException {
      // Если токен протух или его нет, вернем null
      return null;
    }
  }

    // 🆕 Метод для обновления профиля
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      // Dio сам подставит токен благодаря нашему интерсептору!
      await _dio.put('/users/me', data: data);
      return true;
    } on DioException catch (e) {
      // Если сервер вернул ошибку (например, возраст меньше 18)
      print('Ошибка обновления: ${e.response?.data}');
      return false;
    }
  }

    // 🆕 Метод для загрузки аватарки
  Future<bool> uploadAvatar(File imageFile) async {
    try {
      String fileName = imageFile.path.split('/').last;
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(imageFile.path, filename: fileName),
      });
      
      final response = await _dio.post('/users/me/avatar', data: formData);
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Ошибка загрузки аватарки: $e');
      return false;
    }
  }

  // 🆕 Добавим геттер для baseUrl, чтобы фронтенд знал, откуда брать картинки
  static String get baseUrl => 'http://192.168.1.150:8000';

   // 🚪 Метод для выхода из системы
  Future<void> logout() async {
    // Просто удаляем токен из безопасного хранилища
    await _storage.delete(key: 'auth_token');
    print('🚪 Пользователь вышел из системы, токен удалён.');
  }

   // 📸 Загрузка фото в альбом
  Future<bool> uploadPhoto(File imageFile, String albumType) async {
    try {
      String fileName = imageFile.path.split('/').last;
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(imageFile.path, filename: fileName),
        "album_type": albumType,
      });
      
      final response = await _dio.post('/photos/upload', data: formData);
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Ошибка загрузки фото: $e');
      return false;
    }
  }

  // 📥 Получить публичные фото пользователя
  Future<List<dynamic>?> getPublicPhotos(String userId) async {
    try {
      final response = await _dio.get('/photos/public/$userId');
      return response.data;
    } catch (e) {
      return null;
    }
  }

  // 🔒 Получить мои приватные фото
  Future<List<dynamic>?> getMyPrivatePhotos() async {
    try {
      final response = await _dio.get('/photos/private/my');
      // 🆕 Логируем ответ для отладки
      print('🔒 Приватные фото от сервера: ${response.data}');
      print('🔒 Статус ответа: ${response.statusCode}');
      return response.data;
    } catch (e) {
      // 🆕 Логируем ошибку, если она есть
      print('❌ Ошибка получения приватных фото: $e');
      return null;
    }
  }

  // 🔑 Получить приватные фото другого пользователя (если есть доступ)
  Future<List<dynamic>?> getUserPrivatePhotos(String userId) async {
    try {
      final response = await _dio.get('/photos/private/$userId');
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        print('🚫 Нет доступа к приватному альбому');
      }
      return null;
    }
  }

  // 💝 Предоставить доступ к приватному альбому
  Future<bool> grantPrivateAccess(String userId) async {
    try {
      final response = await _dio.post('/photos/private/grant-access', data: {
        'user_id': userId,
      });
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ❌ Отозвать доступ
  Future<bool> revokePrivateAccess(String userId) async {
    try {
      final response = await _dio.delete('/photos/private/revoke-access/$userId');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 👥 Получить список пользователей с доступом
  Future<List<dynamic>?> getAccessList() async {
    try {
      final response = await _dio.get('/photos/private/access-list');
      return response.data;
    } catch (e) {
      return null;
    }
  }

  // 🗑️ Удалить фото
  Future<bool> deletePhoto(String photoId) async {
    try {
      final response = await _dio.delete('/photos/$photoId');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 📅 Создать встречу
  Future<bool> createMeeting(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/meetings/', data: data);
      return response.statusCode == 201;
    } catch (e) {
      print('❌ Ошибка создания встречи: $e');
      return false;
    }
  }

  // 📋 Получить активные встречи
  Future<List<dynamic>?> getActiveMeetings() async {
    try {
      final response = await _dio.get('/meetings/');
      return response.data;
    } catch (e) {
      return null;
    }
  }

  // 👤 Получить мои встречи
  Future<List<dynamic>?> getMyMeetings() async {
    try {
      final response = await _dio.get('/meetings/my');
      return response.data;
    } catch (e) {
      return null;
    }
  }

  // ❌ Отменить встречу
  Future<bool> cancelMeeting(String meetingId) async {
    try {
      final response = await _dio.delete('/meetings/$meetingId');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 💌 Отклик на встречу
  Future<bool> createResponse(String meetingId, String? message) async {
    try {
      final data = {'meeting_id': meetingId};
      if (message != null && message.isNotEmpty) {
        data['response_message'] = message;
      }
      final response = await _dio.post('/responses/', data: data);
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('❌ Ошибка создания отклика: $e');
      return false;
    }
  }

  // 📋 Получить список откликов (только для автора встречи)
  Future<List<dynamic>?> getMeetingResponses(String meetingId) async {
    try {
      final response = await _dio.get('/responses/meeting/$meetingId');
      return response.data;
    } on DioException catch (e) {
      // 🆕 Если 404 — значит пользователь не автор, это нормально!
      if (e.response?.statusCode == 404) {
        return []; // Возвращаем пустой список, чтобы FutureBuilder просто ничего не показал
      }
      print('❌ Ошибка получения откликов: $e');
      return null;
    } catch (e) {
      print('❌ Общая ошибка получения откликов: $e');
      return null;
    }
  }

  // ✅ Обновить статус отклика (принять/отклонить/подтвердить)
  Future<bool> updateResponseStatus(String responseId, String status) async {
    try {
      // Передаем new_status как query-параметр, как мы настроили на бэкенде
      final response = await _dio.put('/responses/$responseId/status?new_status=$status');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Ошибка обновления статуса: $e');
      return false;
    }
  }

  // 💬 Отправить сообщение в чат
  Future<bool> sendMessage(String meetingId, String text) async {
    try {
      final response = await _dio.post('/messages/', data: {
        'meeting_id': meetingId,
        'text': text,
      });
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('❌ Ошибка отправки сообщения: $e');
      return false;
    }
  }

  // 📜 Получить историю сообщений для встречи
  Future<List<dynamic>?> getMeetingMessages(String meetingId) async {
    try {
      final response = await _dio.get('/messages/meeting/$meetingId');
      return response.data;
    } catch (e) {
      print('❌ Ошибка получения сообщений: $e');
      return null;
    }
  }

  // 🏁 Пометить все входящие сообщения как прочитанные
  Future<void> markMessagesAsRead(String meetingId) async {
    try {
      await _dio.put('/messages/meeting/$meetingId/read');
    } catch (e) {
      print('❌ Ошибка пометки сообщений: $e');
    }
  }

  // 📋 Получить мои отклики (заявки на чужие встречи)
  Future<List<dynamic>?> getMyResponses() async {
    try {
      final response = await _dio.get('/responses/my');
      return response.data;
    } catch (e) {
      print('❌ Ошибка получения моих откликов: $e');
      return null;
    }
  }

  // 👤 Получить публичный профиль пользователя и его фото по ID
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final response = await _dio.get('/users/$userId/public');
      return response.data;
    } catch (e) {
      print('❌ Ошибка получения профиля пользователя: $e');
      return null;
    }
  }

  // 💬 Получить список всех моих чатов
  Future<List<dynamic>?> getMyChats() async {
    try {
      final response = await _dio.get('/messages/my');
      return response.data;
    } catch (e) {
      print('❌ Ошибка получения списка чатов: $e');
      return null;
    }
  }  
}