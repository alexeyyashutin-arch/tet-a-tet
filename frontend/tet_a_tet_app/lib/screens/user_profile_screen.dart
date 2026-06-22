import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../utils/url_helper.dart';
import '../widgets/app_background.dart';

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
    final userData = await _api.getUserById(widget.userId);
    
    if (mounted) {
      setState(() {
        _user = userData?['user'];
        _photos = userData?['photos'] ?? [];
        _isLoading = false;
      });
    }
  }

  bool _hasAnyNewProfileFields() {
    return _user?['height'] != null ||
           _user?['weight'] != null ||
           _user?['body_type'] != null ||
           _user?['alcohol_attitude'] != null ||
           _user?['smoking_attitude'] != null ||
           _user?['marital_status'] != null ||
           _user?['has_children'] != null;
  }

  Widget _buildInfoBadge(IconData icon, String text) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: theme.primaryColor, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.montserrat(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: theme.primaryColor)),
      );
    }

    if (_user == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: theme.textTheme.bodyLarge?.color),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(
            'Пользователь не найден',
            style: GoogleFonts.montserrat(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
        ),
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
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: theme.textTheme.bodyLarge?.color),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'ПРОФИЛЬ',
                style: GoogleFonts.montserrat(
                  color: theme.textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  fontSize: 16,
                ),
              ),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: AppBackground(
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
                                imageUrl: UrlHelper.getImageUrl(_user!['avatar_url'], ApiService.baseUrl),
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: theme.cardTheme.color,
                                  child: Center(child: CircularProgressIndicator(color: theme.primaryColor)),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: theme.cardTheme.color,
                                  child: Icon(Icons.person, size: 80, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
                                ),
                              )
                            : Container(
                                color: theme.cardTheme.color,
                                child: Icon(Icons.person, size: 80, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
                              ),
                      ),
                      Container(
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              theme.scaffoldBackgroundColor.withValues(alpha: 0.95),
                              theme.scaffoldBackgroundColor.withValues(alpha: 0.6),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                        child: Row(
                          children: [
                            Icon(genderIcon, color: genderColor, size: 24),
                            const SizedBox(width: 10),
                            Text(
                              nameWithAge,
                              style: GoogleFonts.montserrat(
                                color: theme.textTheme.bodyLarge?.color,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
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
                      Icon(Icons.location_on, color: theme.primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        city,
                        style: GoogleFonts.montserrat(
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 🌟 СЕКЦИЯ: ОБО МНЕ
              if ((bio != null && bio.isNotEmpty) || _hasAnyNewProfileFields()) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ОБО МНЕ',
                          style: GoogleFonts.montserrat(
                            color: theme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        if (bio != null && bio.isNotEmpty) ...[
                          Text(
                            bio,
                            style: GoogleFonts.montserrat(
                              color: theme.textTheme.bodyLarge?.color,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                          if (_hasAnyNewProfileFields()) ...[
                            const SizedBox(height: 16),
                            Divider(color: theme.primaryColor, height: 1, thickness: 0.5),
                            const SizedBox(height: 16),
                          ],
                        ],

                        if (_hasAnyNewProfileFields()) ...[
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              if (_user?['height'] != null) _buildInfoBadge(Icons.height, '${_user!['height']} см'),
                              if (_user?['weight'] != null) _buildInfoBadge(Icons.monitor_weight, '${_user!['weight']} кг'),
                              if (_user?['body_type'] != null) _buildInfoBadge(Icons.fitness_center, _user!['body_type']),
                              if (_user?['alcohol_attitude'] != null) _buildInfoBadge(Icons.wine_bar, _user!['alcohol_attitude']),
                              if (_user?['smoking_attitude'] != null) _buildInfoBadge(Icons.smoke_free, _user!['smoking_attitude']),
                              if (_user?['marital_status'] != null) _buildInfoBadge(Icons.favorite_outline, _user!['marital_status']),
                              if (_user?['has_children'] != null) _buildInfoBadge(Icons.child_care, _user!['has_children'] == 'Есть' ? 'Есть дети' : 'Нет детей'),
                            ],
                          ),
                        ],
                      ],
                    ),
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
                    Text(
                      'АЛЬБОМ',
                      style: GoogleFonts.montserrat(
                        color: theme.primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_photos.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
                        ),
                        child: Center(
                          child: Text(
                            'Альбом пуст',
                            style: GoogleFonts.montserrat(
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _photos.length,
                        itemBuilder: (context, index) {
                          final photoUrl = _photos[index]['photo_url'];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: UrlHelper.getImageUrl(photoUrl, ApiService.baseUrl),
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: theme.cardTheme.color,
                                child: Center(child: CircularProgressIndicator(color: theme.primaryColor, strokeWidth: 2)),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: theme.cardTheme.color,
                                child: Icon(Icons.broken_image, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
                              ),
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