import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tet_a_tet_app/screens/albums_screen.dart';
import '../services/api_service.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/background_pattern.dart';
import 'meetings_feed_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  List<dynamic> _myMeetings = [];

  // Переменные для аватарки
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await _api.getProfile();
    final meetings = await _api.getMyMeetings(); // 🆕 Загружаем встречи
    
    if (mounted) {
      setState(() {
        _profile = data;
        _myMeetings = meetings ?? []; // 🆕 Сохраняем их
        _isLoading = false;
      });
    }
  }

  // Метод для выбора и загрузки фото
  Future<void> _pickAndUploadAvatar() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _isUploadingAvatar = true;
      });

      final success = await _api.uploadAvatar(_selectedImage!);
      
      setState(() => _isUploadingAvatar = false);

      if (success) {
        // После успешной загрузки обновляем профиль, чтобы подтянуть новую ссылку
        await _loadProfile();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Аватарка успешно обновлена! 😍'), backgroundColor: Colors.green),
        );
      } else {
        setState(() => _selectedImage = null); // Откат, если не удалось
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить фото'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor = const Color(0xFFD4AF37);

    return Scaffold(
      // backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        // backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text(
          'Мой Профиль',
          style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFFD4AF37)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(currentProfile: _profile ?? {}),
                ),
              ).then((_) => _loadProfile());
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFD4AF37)),
            onPressed: () async {
              // Показываем красивое подтверждение (опционально, но очень по-взрослому)
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: const Text('Выход', style: TextStyle(color: Colors.white)),
                  content: const Text('Вы уверены, что хотите выйти из клуба?', style: TextStyle(color: Colors.grey)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Выйти', style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
    
              if (shouldLogout == true) {
                // 1. Удаляем токен
                await _api.logout();
                
                // 2. Возвращаемся на экран входа и очищаем ВСЮ историю навигации!
                // (чтобы кнопка "Назад" на телефоне не вернула нас обратно в профиль)
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false, // Удаляем все предыдущие экраны из стека
                );
              }
            },
          ),
        ],
      ),
      body: BackgroundPattern(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
            : _profile == null
                ? const Center(child: Text('Ошибка загрузки профиля', style: TextStyle(color: Colors.red)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        // 🌟 ИНТЕРАКТИВНАЯ АВАТАРКА 🌟
                        GestureDetector(
                          onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: const Color(0xFF1E1E1E),
                                backgroundImage: _selectedImage != null 
                                    ? FileImage(_selectedImage!) as ImageProvider 
                                    : (_profile!['avatar_url'] != null 
                                        ? CachedNetworkImageProvider('${ApiService.baseUrl}${_profile!['avatar_url']}')
                                        : null),
                                child: _selectedImage == null && _profile!['avatar_url'] == null
                                    ? const Icon(Icons.person, size: 60, color: Color(0xFFD4AF37))
                                    : null,
                              ),
                              // Иконка камеры поверх аватарки
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD4AF37),
                                  shape: BoxShape.circle,
                                ),
                                child: _isUploadingAvatar
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                    : const Icon(Icons.camera_alt, color: Colors.black, size: 20),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
            
                        // Имя
                        Text(
                          _profile!['username'] ?? 'Твоё имя',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
            
                        // Возраст и пол
                        Text(
                          _buildAgeAndGender(),
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        const SizedBox(height: 32),
            
                        // Карточка с описанием
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'О себе',
                                style: TextStyle(color: Color(0xFFD4AF37), fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _profile!['bio'] ?? 'Здесь пока пусто. Расскажи о себе, чтобы найти идеальную пару...',
                                style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
            
                        // Номер телефона
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.phone_android, color: Color(0xFFD4AF37)),
                              const SizedBox(width: 16),
                              Text(
                                _profile!['phone'] ?? '',
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 32),
                      
                      // Заголовок секции
                      const Padding(
                        padding: EdgeInsets.only(left: 4.0),
                        child: Text(
                          'Мои встречи',
                          style: TextStyle(
                            color: Color(0xFFD4AF37), 
                            fontSize: 18, 
                            fontWeight: FontWeight.bold, 
                            letterSpacing: 1
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      //  Активные встречи
                      ..._myMeetings
                          .where((m) => m['status'] == 'active')
                          .map((m) => _buildActiveMeetingCard(m))
                          .toList(),
                      
                      // 📦 Архив (раскрывающийся список)
                      if (_myMeetings.any((m) => m['status'] != 'active'))
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: const Text(
                                'Архив встреч', 
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                              ),
                              trailing: const Icon(Icons.expand_more, color: Color(0xFFD4AF37)),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
                                  child: Column(
                                    children: _myMeetings
                                        .where((m) => m['status'] != 'active')
                                        .map((m) => _buildArchiveMeetingCard(m))
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),                        
                      ],
                    ),
                  ),
      ),
    );
  }

  String _buildAgeAndGender() {
    final age = _profile?['age'];
    final gender = _profile?['gender'];
    
    String text = '';
    if (age != null) text += '$age ';
    if (gender == 'male') text += '• Мужчина';
    if (gender == 'female') text += '• Женщина';
    
    return text.isEmpty ? 'Заполни свой профиль' : text;
  }

    Widget _buildActiveMeetingCard(Map<String, dynamic> meeting) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            meeting['title'],
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Color(0xFFD4AF37), size: 16),
              const SizedBox(width: 6),
              Text(
                '${meeting['meeting_date']} в ${meeting['meeting_time']}',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
          if (meeting['location'] != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFFD4AF37), size: 16),
                const SizedBox(width: 6),
                Text(
                  meeting['location'],
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1E1E),
                    title: const Text('Отменить встречу?', style: TextStyle(color: Colors.white)),
                    content: const Text('Вы уверены?', style: TextStyle(color: Colors.grey)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Нет')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Да', style: TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _api.cancelMeeting(meeting['id'].toString());
                  _loadProfile(); // Перезагружаем, чтобы обновить список
                }
              },
              icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 18),
              label: const Text('Отменить', style: TextStyle(color: Colors.redAccent)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveMeetingCard(Map<String, dynamic> meeting) {
    final isCancelled = meeting['status'] == 'cancelled';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meeting['title'],
                  style: TextStyle(
                    color: Colors.grey, 
                    fontSize: 14, 
                    fontWeight: FontWeight.bold,
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${meeting['meeting_date']} в ${meeting['meeting_time']}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isCancelled ? Colors.redAccent.withOpacity(0.1) : Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isCancelled ? 'Отменена' : 'Завершена',
              style: TextStyle(
                color: isCancelled ? Colors.redAccent : Colors.green,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}