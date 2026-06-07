import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tet_a_tet_app/screens/album_screen.dart';
import '../services/api_service.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/background_pattern.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  
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
    setState(() {
      _profile = data;
      _isLoading = false;
    });
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
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text(
          'Мой Профиль',
          style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        actions: [
          // Кнопка альбомов
          IconButton(
            icon: const Icon(Icons.photo_library, color: Color(0xFFD4AF37)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AlbumsScreen(
                    userId: _profile!['id'].toString(),
                    isMyProfile: true,
                  ),
                ),
              );
            },
          ),
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
}