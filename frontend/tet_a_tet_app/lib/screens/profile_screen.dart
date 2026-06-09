import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/background_pattern.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _profile;
  List<dynamic> _myMeetings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await _api.getProfile();
    final meetings = await _api.getMyMeetings();
    
    if (mounted) {
      setState(() {
        _profile = data;
        _myMeetings = meetings ?? [];
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

    final username = _profile?['username'] ?? 'Аноним';
    final age = _profile?['age'];
    final nameWithAge = age != null ? '$username, $age' : username;
    final isFemale = _profile?['gender'] == 'female' || _profile?['gender'] == 'ж';
    final genderIcon = isFemale ? Icons.female : Icons.male;
    final genderColor = isFemale ? const Color(0xFFEC407A) : const Color(0xFF4FC3F7);
    final phone = _profile?['phone'] ?? 'Не указан';

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
              centerTitle: true,
              title: Text(
                'ПРОФИЛЬ',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  fontSize: 16,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
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
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: () async {
                    await _api.logout();
                    if (mounted) {
                      // 🆕 Используем pushAndRemoveUntil с MaterialPageRoute
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false, // Удаляем ВСЕ предыдущие маршруты
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: BackgroundPattern(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            0, 
            MediaQuery.of(context).padding.top + kToolbarHeight, 
            0, 
            MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 👑 БОЛЬШАЯ КВАДРАТНАЯ АВАТАРКА
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24), // Закруглённые углы рамки
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // 🆕 AspectRatio делает блок идеально квадратным (1 к 1)!
                      AspectRatio(
                        aspectRatio: 1.0, 
                        child: _profile?['avatar_url'] != null // В meeting_detail_screen здесь будет meeting['creator_avatar_url']
                            ? CachedNetworkImage(
                                imageUrl: '${ApiService.baseUrl}${_profile!['avatar_url']}', // Или meeting['creator_avatar_url']
                                fit: BoxFit.cover, // Важно: cover красиво заполнит квадрат, обрезав лишнее по краям
                                placeholder: (context, url) => Container(
                                  color: const Color(0xFF1E1E1E),
                                  child: const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: const Color(0xFF1E1E1E),
                                  child: const Icon(Icons.person, size: 80, color: Colors.white54),
                                ),
                              )
                            : Container(
                                color: const Color(0xFF1E1E1E),
                                child: const Icon(Icons.person, size: 80, color: Colors.white54),
                              ),
                      ),
                      // Градиент и текст снизу
                      Container(
                        height: 90, // Чуть уменьшил высоту градиента, чтобы на квадратном фото он не перекрывал слишком много лица 😉
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.95),
                              Colors.black.withOpacity(0.6),
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
                                color: Colors.white,
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

              // 📞 Контактная информация (Стеклянная карточка)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'КОНТАКТЫ',
                        style: GoogleFonts.montserrat(
                          color: const Color(0xFFD4AF37),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.phone, color: Color(0xFFD4AF37), size: 20),
                          const SizedBox(width: 12),
                          Text(
                            phone,
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              const SizedBox(height: 32),

              const SizedBox(height: 32),

              // 📦 Архив встреч (разворачивающийся)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Показываем блок, только если есть архивные встречи
                    if (_myMeetings.where((m) => m['status'] != 'active').isNotEmpty) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent), // Убираем лишнюю линию разделителя
                          child: ExpansionTile(
                            title: Text(
                              'АРХИВ ВСТРЕЧ', 
                              style: GoogleFonts.montserrat(
                                color: Colors.white, 
                                fontSize: 14, 
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              )
                            ),
                            iconColor: const Color(0xFFD4AF37),
                            collapsedIconColor: const Color(0xFFD4AF37),
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
                    ] else ...[
                      // Если архив пуст, просто показываем аккуратную заглушку
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                        ),
                        child: Center(
                          child: Text(
                            'Архив встреч пуст',
                            style: GoogleFonts.montserrat(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
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

  // 🃏 Карточка активной встречи (упрощенная и стильная)
  Widget _buildActiveMeetingCard(Map<String, dynamic> meeting) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            meeting['title'],
            style: GoogleFonts.montserrat(
              color: Colors.white, 
              fontSize: 15, 
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Color(0xFFD4AF37), size: 16),
              const SizedBox(width: 6),
              Text(
                '${meeting['meeting_date']} в ${meeting['meeting_time']}',
                style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          if (meeting['location'] != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFFD4AF37), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    meeting['location'],
                    style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 13),
                  ),
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
                  _loadProfile();
                }
              },
              icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 18),
              label: const Text('Отменить', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // 📦 Карточка архивной встречи
  Widget _buildArchiveMeetingCard(Map<String, dynamic> meeting) {
    final isCancelled = meeting['status'] == 'cancelled';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
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
                  style: GoogleFonts.montserrat(
                    color: Colors.grey, 
                    fontSize: 14, 
                    fontWeight: FontWeight.w500,
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${meeting['meeting_date']} в ${meeting['meeting_time']}',
                  style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isCancelled ? Colors.redAccent.withOpacity(0.1) : Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCancelled ? Colors.redAccent.withOpacity(0.3) : Colors.green.withOpacity(0.3),
              ),
            ),
            child: Text(
              isCancelled ? 'Отменена' : 'Завершена',
              style: GoogleFonts.montserrat(
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