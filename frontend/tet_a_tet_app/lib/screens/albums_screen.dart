import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/background_pattern.dart';

class AlbumsScreen extends StatefulWidget {
  final String? userId;
  final bool isMyProfile;

  const AlbumsScreen({
    super.key,
    this.userId,
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
    
    if (widget.userId == null) {
      _loadMyUserId();
    } else {
      _currentUserId = widget.userId;
      _loadPublicPhotos();
      _loadPrivatePhotos();
    }
  }

  Future<void> _loadMyUserId() async {
    final profile = await _api.getProfile();
    if (profile != null && mounted) {
      setState(() {
        _currentUserId = profile['id'].toString();
      });
      _loadPublicPhotos();
      _loadPrivatePhotos();
    } else if (mounted) {
      setState(() {
        _isLoadingPublic = false;
        _isLoadingPrivate = false;
      });
    }
  }

  Future<void> _loadPublicPhotos() async {
    if (_currentUserId == null) return;
    setState(() => _isLoadingPublic = true);
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
            content: Text('Фото загружено в ${albumType == "public" ? "публичный" : "приватный"} альбом! 📸'),
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
          const SnackBar(content: Text('Не удалось загрузить фото'), backgroundColor: Colors.redAccent),
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
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 48.0), // Высота AppBar + TabBar
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: Colors.black.withOpacity(0.3),
              elevation: 0,
              centerTitle: true,
              title: Text(
                'ФОТОАЛЬБОМЫ',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  fontSize: 16,
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFD4AF37),
                labelColor: const Color(0xFFD4AF37),
                unselectedLabelColor: Colors.grey,
                labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 13),
                tabs: const [
                  Tab(text: 'ПУБЛИЧНЫЙ'),
                  Tab(text: 'ПРИВАТНЫЙ 🔒'),
                ],
              ),
            ),
          ),
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
          ? Padding(
              // 🆕 Простой и надежный отступ: 80 пикселей снизу гарантированно поднимут кнопку над меню
              padding: const EdgeInsets.only(bottom: 80.0, right: 16.0),
              child: FloatingActionButton(
                backgroundColor: const Color(0xFFD4AF37),
                elevation: 8,
                onPressed: () => _showAlbumTypeDialog(),
                child: const Icon(Icons.add_a_photo, color: Colors.black),
              ),
            )
          : null,
    );
  }

  Widget _buildAlbumTab(String albumType, List<dynamic> photos, bool isLoading) {
    // SafeArea автоматически отодвинет контент от статус-бара (часов).
    // Padding(top: 112) опустит его ровно под AppBar (56) + TabBar (48) + 8px воздуха.
    // Padding(bottom: 80) поднимет контент над нижним меню.
    return SafeArea(
      top: true,
      bottom: false, // Кнопка "+" сама позаботится о нижнем отступе
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10.0, 16, 80.0),
        child: _buildInnerContent(albumType, photos, isLoading),
      ),
    );
  }

  // Вынесла внутренности в отдельный метод для чистоты кода
  Widget _buildInnerContent(String albumType, List<dynamic> photos, bool isLoading) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
      );
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
              style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 16),
            ),
            if (!widget.isMyProfile && albumType == 'private')
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('Нет доступа', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
              ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return GestureDetector(
          onTap: () => _showPhotoDialog(photo['url']),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: '${ApiService.baseUrl}${photo['url']}',
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  memCacheWidth: 300,
                  placeholder: (context, url) => Container(
                    color: const Color(0xFF1E1E1E),
                    child: const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37), strokeWidth: 2)),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
                ),
                if (widget.isMyProfile)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => _deletePhoto(photo['id'], index, albumType),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                      ),
                    ),
                  ),
              ],
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
        title: Text('Загрузить фото', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('В какой альбом загрузить фото?', style: GoogleFonts.montserrat(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _uploadPhoto('public');
            },
            child: Text('ПУБЛИЧНЫЙ', style: GoogleFonts.montserrat(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _uploadPhoto('private');
            },
            child: Text('ПРИВАТНЫЙ 🔒', style: GoogleFonts.montserrat(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
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
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: '${ApiService.baseUrl}$photoUrl',
                fit: BoxFit.contain,
                memCacheWidth: 1200,
                placeholder: (context, url) => const CircularProgressIndicator(color: Color(0xFFD4AF37)),
                errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
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