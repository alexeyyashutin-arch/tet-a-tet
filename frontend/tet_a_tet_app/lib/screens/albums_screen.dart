import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'dart:async';
import '../widgets/app_background.dart';
import '../utils/url_helper.dart';

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

class _AlbumsScreenState extends State<AlbumsScreen> with TickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabController;
  
  List<dynamic> _publicPhotos = [];
  List<dynamic> _privatePhotos = [];
  bool _isLoadingPublic = true;
  bool _isLoadingPrivate = false;
  String? _error;
  String? _currentUserId;
  
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState(); // 🆕 Исправила опечатку (было super.initState;)
    _tabController = TabController(length: 2, vsync: this);
    
    _tabController.addListener(() {
      if (_isEditMode) {
        setState(() {
          _isEditMode = false;
        });
      }
    });

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

  // Future<void> _deletePhoto(String photoId, int index, String albumType) async {
  //   final confirm = await showDialog<bool>(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       backgroundColor: const Color(0xFF1E1E1E),
  //       title: const Text('Удалить фото?', style: TextStyle(color: Colors.white)),
  //       content: const Text('Это действие нельзя отменить.', style: TextStyle(color: Colors.grey)),
  //       actions: [
  //         TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
  //         TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.redAccent))),
  //       ],
  //     ),
  //   );

  //   if (confirm == true) {
  //     final success = await _api.deletePhoto(photoId);
  //     if (success && mounted) {
  //       setState(() {
  //         if (albumType == 'public') {
  //           _publicPhotos.removeAt(index);
  //         } else {
  //           _privatePhotos.removeAt(index);
  //         }
  //       });
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Фото удалено'), backgroundColor: Colors.green),
  //       );
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 48.0),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
              elevation: 0,
              centerTitle: true,
              title: Text(
                'ФОТОАЛЬБОМЫ',
                style: GoogleFonts.montserrat(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  fontSize: 16,
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: theme.primaryColor,
                labelColor: theme.primaryColor,
                unselectedLabelColor: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5) ?? Colors.grey,
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
      body: AppBackground(
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
              padding: const EdgeInsets.only(bottom: 80.0, right: 16.0),
              child: FloatingActionButton(
                backgroundColor: theme.primaryColor,
                elevation: 8,
                onPressed: () {
                  setState(() {
                    _isEditMode = !_isEditMode;
                    if (!_isEditMode) {
                      final currentAlbumType = _tabController.index == 0 ? 'public' : 'private';
                      final currentPhotos = _tabController.index == 0 ? _publicPhotos : _privatePhotos;
                      _savePhotoOrder(currentAlbumType, currentPhotos);
                    }
                  });
                },
                child: Icon(
                  _isEditMode ? Icons.check : Icons.edit_outlined,
                  color: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                  size: 28,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildAlbumTab(String albumType, List<dynamic> photos, bool isLoading) {
    return SafeArea(
      top: true,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10.0, 16, 80.0),
        child: _buildInnerContent(albumType, photos, isLoading),
      ),
    );
  }

  Widget _buildInnerContent(String albumType, List<dynamic> photos, bool isLoading) {
    final theme = Theme.of(context);
    
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.primaryColor),
      );
    }

    if (photos.isEmpty && !widget.isMyProfile) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              albumType == 'public' ? Icons.photo_library : Icons.lock,
              size: 64,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              albumType == 'public' ? 'Пока нет публичных фото' : 'Приватный альбом пуст',
              style: GoogleFonts.montserrat(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            if (!widget.isMyProfile && albumType == 'private')
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Нет доступа',
                  style: GoogleFonts.montserrat(color: Colors.redAccent, fontSize: 14),
                ),
              ),
          ],
        ),
      );
    }

    if (_isEditMode) {
      return _buildReorderableGrid(albumType, photos);
    }
    
    return _buildNormalGrid(albumType, photos);
  }

  Widget _buildNormalGrid(String albumType, List<dynamic> photos) {
    final theme = Theme.of(context);
    List<Widget> gridChildren = [];

    for (int i = 0; i < photos.length; i++) {
      final photo = photos[i];
      gridChildren.add(
        AnimatedGridItem(
          index: i,
          child: GestureDetector(
            key: ValueKey(photo['id']),
            onTap: () {
              _showPhotoDialog(photo['url'], i, albumType);
            },
            child: Hero(
              tag: 'photo_${albumType}_$i',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: UrlHelper.getImageUrl(photo['url'], ApiService.baseUrl),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      memCacheWidth: 300,
                      placeholder: (context, url) => Container(
                        color: theme.cardTheme.color,
                        child: Center(child: CircularProgressIndicator(color: theme.primaryColor, strokeWidth: 2)),
                      ),
                      errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.red),
                    ),
                    if (i == 0 && albumType == 'public')
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.star,
                            color: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (widget.isMyProfile) {
      gridChildren.add(
        AnimatedGridItem(
          index: photos.length,
          child: GestureDetector(
            key: const ValueKey('add_photo_placeholder'),
            onTap: _showAlbumTypeDialog,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.primaryColor.withValues(alpha: 0.6), width: 2),
                borderRadius: BorderRadius.circular(12),
                color: theme.cardTheme.color,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo, color: theme.primaryColor, size: 36),
                    const SizedBox(height: 4),
                    Text(
                      'Добавить',
                      style: GoogleFonts.montserrat(
                        color: theme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      padding: EdgeInsets.zero,
      children: gridChildren,
    );
  }

  Widget _buildReorderableGrid(String albumType, List<dynamic> photos) {
    final theme = Theme.of(context);
    List<Widget> gridChildren = [];

    for (int i = 0; i < photos.length; i++) {
      final photo = photos[i];
      gridChildren.add(
        GestureDetector(
          key: ValueKey(photo['id']),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: UrlHelper.getImageUrl(photo['url'], ApiService.baseUrl),
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  memCacheWidth: 300,
                  placeholder: (context, url) => Container(
                    color: theme.cardTheme.color,
                    child: Center(child: CircularProgressIndicator(color: theme.primaryColor, strokeWidth: 2)),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(Icons.drag_indicator, color: theme.primaryColor, size: 40),
                  ),
                ),
                if (widget.isMyProfile)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _deletePhoto(photo['id'], i, albumType),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return ReorderableGridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      padding: EdgeInsets.zero,
      children: gridChildren,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          final item = photos.removeAt(oldIndex);
          photos.insert(newIndex, item);
        });
      },
    );
  }

  Future<void> _savePhotoOrder(String albumType, List<dynamic> photos) async {
    final photoIds = photos.map((p) => p['id'].toString()).toList();
    final success = await _api.reorderPhotos(albumType, photoIds);
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Порядок сохранён! ✨'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showAlbumTypeDialog() {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text(
          'Загрузить фото',
          style: GoogleFonts.montserrat(
            color: theme.textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'В какой альбом загрузить фото?',
          style: GoogleFonts.montserrat(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _uploadPhoto('public');
            },
            child: Text(
              'ПУБЛИЧНЫЙ',
              style: GoogleFonts.montserrat(
                color: theme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _uploadPhoto('private');
            },
            child: Text(
              'ПРИВАТНЫЙ 🔒',
              style: GoogleFonts.montserrat(
                color: theme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePhoto(String photoId, int index, String albumType) async {
    final theme = Theme.of(context);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text(
          'Удалить фото?',
          style: GoogleFonts.montserrat(color: theme.textTheme.bodyLarge?.color),
        ),
        content: Text(
          'Это действие нельзя отменить.',
          style: GoogleFonts.montserrat(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Отмена',
              style: GoogleFonts.montserrat(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Удалить', style: GoogleFonts.montserrat(color: Colors.redAccent)),
          ),
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

  void _showPhotoDialog(String photoUrl, int index, String albumType) {
    final theme = Theme.of(context);
    
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                Center(
                  child: Hero(
                    tag: 'photo_${albumType}_$index',
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: CachedNetworkImage(
                        imageUrl: UrlHelper.getImageUrl(photoUrl, ApiService.baseUrl),
                        fit: BoxFit.contain,
                        memCacheWidth: 1200,
                        placeholder: (context, url) => CircularProgressIndicator(color: theme.primaryColor),
                        errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                if (widget.isMyProfile && albumType == 'public')
                  Positioned(
                    bottom: MediaQuery.of(context).padding.bottom + 24,
                    left: 24,
                    right: 24,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final photos = albumType == 'public' ? _publicPhotos : _privatePhotos;
                        final photoId = photos[index]['id'].toString();
                        final success = await _api.setAvatar(photoId);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success ? 'Фото установлено как аватарка! 📸' : 'Не удалось установить'),
                              backgroundColor: success ? Colors.green : Colors.redAccent,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.star, size: 20),
                      label: Text(
                        'СДЕЛАТЬ АВАТАРКОЙ',
                        style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return child;
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// 🆕 Отдельный виджет для каскадной анимации (вне класса _AlbumsScreenState)
class AnimatedGridItem extends StatefulWidget {
  final Widget child;
  final int index;

  const AnimatedGridItem({super.key, required this.child, required this.index});

  @override
  State<AnimatedGridItem> createState() => _AnimatedGridItemState();
}

class _AnimatedGridItemState extends State<AnimatedGridItem> {
  double _opacity = 0.0;
  double _offsetY = 30.0;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) {
        setState(() {
          _opacity = 1.0;
          _offsetY = 0.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: _opacity,
      child: Transform.translate(
        offset: Offset(0, _offsetY),
        child: widget.child,
      ),
    );
  }
}