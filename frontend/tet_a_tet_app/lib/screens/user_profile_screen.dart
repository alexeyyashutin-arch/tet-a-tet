import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/background_pattern.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _user;
  List<dynamic> _photos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // 🆕 Загружаем данные пользователя по ID
    final userData = await _api.getUserById(widget.userId);
    
    if (mounted) {
      setState(() {
        _user = userData?['user'];
        _photos = userData?['photos'] ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
      );
    }

    if (_user == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))),
        body: const Center(child: Text('Пользователь не найден', style: TextStyle(color: Colors.grey))),
      );
    }

    final username = _user!['username'] ?? 'Аноним';
    final age = _user!['age'];
    final nameWithAge = age != null ? '$username, $age' : username;
    final isFemale = _user!['gender'] == 'female' || _user!['gender'] == 'ж';
    final genderIcon = isFemale ? Icons.female : Icons.male;
    final genderColor = isFemale ? const Color(0xFFEC407A) : const Color(0xFF4FC3F7);
    final bio = _user!['bio'];
    final city = _user!['city'];

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: Colors.black.withOpacity(0.3),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'ПРОФИЛЬ',
                style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2.0, fontSize: 16),
              ),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: BackgroundPattern(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(0, MediaQuery.of(context).padding.top + kToolbarHeight, 0, MediaQuery.of(context).padding.bottom + 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 👑 БОЛЬШАЯ КВАДРАТНАЯ АВАТАРКА
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      AspectRatio(
                        aspectRatio: 1.0,
                        child: _user!['avatar_url'] != null
                            ? CachedNetworkImage(
                                imageUrl: '${ApiService.baseUrl}${_user!['avatar_url']}',
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: const Color(0xFF1E1E1E), child: const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))),
                                errorWidget: (context, url, error) => Container(color: const Color(0xFF1E1E1E), child: const Icon(Icons.person, size: 80, color: Colors.white54)),
                              )
                            : Container(color: const Color(0xFF1E1E1E), child: const Icon(Icons.person, size: 80, color: Colors.white54)),
                      ),
                      Container(
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withOpacity(0.95), Colors.black.withOpacity(0.6), Colors.transparent],
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                        child: Row(
                          children: [
                            Icon(genderIcon, color: genderColor, size: 24),
                            const SizedBox(width: 10),
                            Text(nameWithAge, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 📍 Город (если есть)
              if (city != null && city.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFFD4AF37), size: 20),
                      const SizedBox(width: 8),
                      Text(city, style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 15)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 📝 О себе
              if (bio != null && bio.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('О СЕБЕ', style: GoogleFonts.montserrat(color: const Color(0xFFD4AF37), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      const SizedBox(height: 8),
                      Text(bio, style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 15, height: 1.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // 📸 Альбом фотографий
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('АЛЬБОМ', style: GoogleFonts.montserrat(color: const Color(0xFFD4AF37), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    const SizedBox(height: 12),
                    if (_photos.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3))),
                        child: Center(child: Text('Альбом пуст', style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 14))),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                        itemCount: _photos.length,
                        itemBuilder: (context, index) {
                          final photoUrl = _photos[index]['photo_url'];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: '${ApiService.baseUrl}$photoUrl',
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(color: const Color(0xFF1E1E1E), child: const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37), strokeWidth: 2))),
                              errorWidget: (context, url, error) => Container(color: const Color(0xFF1E1E1E), child: const Icon(Icons.broken_image, color: Colors.white54)),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}