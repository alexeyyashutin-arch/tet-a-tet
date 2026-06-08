import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/background_pattern.dart';

class AlbumsScreen extends StatefulWidget {
  final String? userId;  // 🆕 Делаем nullable!
  final bool isMyProfile;

  const AlbumsScreen({
    super.key,
    this.userId,  // 🆕 Убираем required!
    this.isMyProfile = true,
  });

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabController;
  
  List<dynamic> _publicPhotos = [];
  List<dynamic> _privatePhotos = [];
  bool _isLoadingPublic = true;
  bool _isLoadingPrivate = false;
  String? _error;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Если ID не передали (мы в нижнем меню), узнаем свой ID
    if (widget.userId == null) {
      _loadMyUserId();
    } else {
      _currentUserId = widget.userId;
      _loadPublicPhotos();
      _loadPrivatePhotos();
    }
  }

  // 🆕 Новый метод — узнаём свой ID через профиль
  Future<void> _loadMyUserId() async {
    final profile = await _api.getProfile();
    if (profile != null && mounted) {
      setState(() {
        _currentUserId = profile['id'].toString();
      });
      // Теперь, когда ID есть, загружаем оба альбома
      _loadPublicPhotos();
      _loadPrivatePhotos();
    } else if (mounted) {
      // Если не удалось получить профиль — останавливаем загрузку
      setState(() {
        _isLoadingPublic = false;
        _isLoadingPrivate = false;
      });
    }
  }

  Future<void> _loadPublicPhotos() async {
    if (_currentUserId == null) return; // Ждём, пока свой ID загрузится
    
    setState(() => _isLoadingPublic = true);
    //  Используем _currentUserId вместо widget.userId
    final photos = await _api.getPublicPhotos(_currentUserId!); 
    
    if (mounted) {
      setState(() {
        _publicPhotos = photos ?? [];
        _isLoadingPublic = false;
      });
    }
  }

  Future<void> _loadPrivatePhotos() async {
    if (_currentUserId == null) return;

    setState(() => _isLoadingPrivate = true);
    
    final photos = widget.isMyProfile 
        ? await _api.getMyPrivatePhotos()
        // 🆕 И здесь тоже используем _currentUserId
        : await _api.getUserPrivatePhotos(_currentUserId!); 
    
    if (mounted) {
      setState(() {
        _privatePhotos = photos ?? [];
        _isLoadingPrivate = false;
      });
    }
  }

  Future<void> _uploadPhoto(String albumType) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      final success = await _api.uploadPhoto(File(image.path), albumType);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Фото загружено в ${albumType == "public" ? "публичный" : "приватный"} альбом!'),
            backgroundColor: Colors.green,
          ),
        );
        if (albumType == "public") {
          _loadPublicPhotos();
        } else {
          _privatePhotos.clear();
          _loadPrivatePhotos();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить фото'), backgroundColor: Colors.red),
        );
      }
    }
  }

    Future<void> _deletePhoto(String photoId, int index, String albumType) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Удалить фото?', style: TextStyle(color: Colors.white)),
        content: const Text('Это действие нельзя отменить.', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _api.deletePhoto(photoId);
      if (success && mounted) {
        setState(() {
          if (albumType == 'public') {
            _publicPhotos.removeAt(index);
          } else {
            _privatePhotos.removeAt(index);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Фото удалено'), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        // backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text('Фотоальбомы', style: TextStyle(color: Color(0xFFD4AF37))),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFD4AF37),
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Публичный'),
            Tab(text: 'Приватный 🔒'),
          ],
        ),
      ),
      body: BackgroundPattern(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildAlbumTab('public', _publicPhotos, _isLoadingPublic),
            _buildAlbumTab('private', _privatePhotos, _isLoadingPrivate),
          ],
        ),
      ),
      floatingActionButton: widget.isMyProfile
          ? FloatingActionButton(
              backgroundColor: const Color(0xFFD4AF37),
              onPressed: () => _showAlbumTypeDialog(),
              child: const Icon(Icons.add_a_photo, color: Colors.black),
            )
          : null,
    );
  }

  Widget _buildAlbumTab(String albumType, List<dynamic> photos, bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
    }

    if (photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              albumType == 'public' ? Icons.photo_library : Icons.lock,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              albumType == 'public' 
                  ? 'Пока нет публичных фото'
                  : 'Приватный альбом пуст',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            if (!widget.isMyProfile && albumType == 'private')
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('Нет доступа', style: TextStyle(color: Colors.redAccent)),
              ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return GestureDetector(
          onTap: () => _showPhotoDialog(photo['url']),
          onLongPress: widget.isMyProfile ? () => _deletePhoto(photo['id'], index, albumType) : null,
          child: Hero(
            tag: photo['id'],
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: '${ApiService.baseUrl}${photo['url']}',
                fit: BoxFit.cover,
                // 🚀 Ограничиваем декодирование в память для сетки
                memCacheWidth: 300,
                placeholder: (context, url) => Container(
                  color: const Color(0xFF1E1E1E),
                  child: const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37), strokeWidth: 2)),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAlbumTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Загрузить фото', style: TextStyle(color: Colors.white)),
        content: const Text('В какой альбом загрузить фото?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _uploadPhoto('public');
            },
            child: const Text('Публичный', style: TextStyle(color: Color(0xFFD4AF37))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _uploadPhoto('private');
            },
            child: const Text('Приватный 🔒', style: TextStyle(color: Color(0xFFD4AF37))),
          ),
        ],
      ),
    );
  }

  void _showPhotoDialog(String photoUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: '${ApiService.baseUrl}$photoUrl',
            fit: BoxFit.contain,
            // 🚀 Для полного экрана берем размер побольше
            memCacheWidth: 1200,
            placeholder: (context, url) => const CircularProgressIndicator(color: Color(0xFFD4AF37)),
            errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}