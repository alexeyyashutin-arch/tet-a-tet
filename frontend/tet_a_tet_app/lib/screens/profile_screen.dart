import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/app_background.dart';
import '../widgets/presigned_image.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'verification_screen.dart';
import 'premium_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _profile;
  List<dynamic> _myMeetings = [];
  List<dynamic> _archivedResponses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final data = await _api.getProfile();
    final response = await _api.getMyMeetings();
    final archived = await _api.getMyArchivedResponses();
    
    if (mounted) {
      setState(() {
        _profile = data;
        _myMeetings = response?['meetings'] ?? []; 
        _archivedResponses = archived ?? [];
        _isLoading = false;
      });
    }
  }

  // 👑 Тот же метод, что в настройках
  Widget _buildGlassCard({required List<Widget> children}) {
    final theme = Theme.of(context);
    
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.primaryColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: children,
          ),
        ),
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

    final username = _profile?['username'] ?? 'Аноним';
    final age = _profile?['age'];
    final nameWithAge = age != null ? '$username, $age' : username;
    final isFemale = _profile?['gender'] == 'female' || _profile?['gender'] == 'ж';
    final genderIcon = isFemale ? Icons.female : Icons.male;
    final genderColor = isFemale ? const Color(0xFFEC407A) : const Color(0xFF4FC3F7);
    final phone = _profile?['phone'] ?? 'Не указан';

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
              centerTitle: true,
              title: Text(
                'ПРОФИЛЬ',
                style: GoogleFonts.montserrat(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  fontSize: 16,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.settings, color: theme.primaryColor),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: theme.textTheme.bodyLarge?.color),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreen(currentProfile: _profile),
                      ),
                    ).then((_) => loadProfile());
                  },
                ),
                IconButton(
                  icon: Icon(Icons.logout, color: theme.textTheme.bodyLarge?.color),
                  onPressed: () async {
                    await _api.logout();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: AppBackground(
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
              // 💎 ПРЕМИУМ-БЛОК
              // 💎 ПРЕМИУМ-БЛОК
              if (_profile?['is_premium'] == true)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0).copyWith(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PremiumScreen()),
                      );
                    },
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFD4AF37),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'PREMIUM',
                              style: GoogleFonts.montserrat(
                                color: const Color(0xFFD4AF37),
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0).copyWith(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PremiumScreen()),
                      );
                    },
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Купить PREMIUM аккаунт',
                              style: GoogleFonts.montserrat(
                                color: const Color(0xFFD4AF37),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // 👑 БОЛЬШАЯ КВАДРАТНАЯ АВАТАРКА
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  decoration: _profile?['is_premium'] == true
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                        )
                      : null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        AspectRatio(
                          aspectRatio: 1.0,
                          child: _profile?['avatar_url'] != null
                              ? PresignedImage(
                                  photoKey: _profile!['avatar_url'],
                                  fit: BoxFit.cover,
                                  placeholder: Container(
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
                              Row(
                                children: [
                                  Text(
                                    nameWithAge,
                                    style: GoogleFonts.montserrat(
                                      color: theme.textTheme.bodyLarge?.color,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  if (_profile?['is_verified'] == true) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [Color(0xFFD4AF37), Color(0xFFFFD700)],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.verified,
                                        color: Colors.black,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        
              const SizedBox(height: 24),
        
              // 📞 Контактная информация
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildGlassCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'КОНТАКТЫ',
                            style: GoogleFonts.montserrat(
                              color: theme.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.phone, color: theme.primaryColor, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                phone,
                                style: GoogleFonts.montserrat(
                                  color: theme.textTheme.bodyLarge?.color,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        
              const SizedBox(height: 24),
        
              // 🆕 🛡️ Блок верификации
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildVerificationCard(),
              ),
        
              const SizedBox(height: 24),
        
              // 🌟 СЕКЦИЯ: ОБО МНЕ
              if (_profile?['bio'] != null || _hasAnyNewProfileFields()) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildGlassCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
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
                            
                            if (_profile?['bio'] != null && _profile!['bio'].toString().isNotEmpty) ...[
                              Text(
                                _profile!['bio'],
                                style: GoogleFonts.montserrat(
                                  color: theme.textTheme.bodyLarge?.color,
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Divider(color: theme.primaryColor, height: 1, thickness: 0.5),
                              const SizedBox(height: 16),
                            ],
          
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                if (_profile?['height'] != null) _buildInfoBadge(Icons.height, '${_profile!['height']} см'),
                                if (_profile?['weight'] != null) _buildInfoBadge(Icons.monitor_weight, '${_profile!['weight']} кг'),
                                if (_profile?['body_type'] != null) _buildInfoBadge(Icons.fitness_center, _profile!['body_type']),
                                if (_profile?['alcohol_attitude'] != null) _buildInfoBadge(Icons.wine_bar, _profile!['alcohol_attitude']),
                                if (_profile?['smoking_attitude'] != null) _buildInfoBadge(Icons.smoke_free, _profile!['smoking_attitude']),
                                if (_profile?['marital_status'] != null) _buildInfoBadge(Icons.favorite_outline, _profile!['marital_status']),
                                if (_profile?['has_children'] != null) _buildInfoBadge(Icons.child_care, _profile!['has_children'] == 'Есть' ? 'Есть дети' : 'Нет детей'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
        
              const SizedBox(height: 32),
        
              // 📦 Архив встреч
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_myMeetings.where((m) => _isArchivedMeeting(m)).isNotEmpty) ...[
                      _buildGlassCard(
                        children: [
                          Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: Text(
                                'АРХИВ ВСТРЕЧ', 
                                style: GoogleFonts.montserrat(
                                  color: theme.textTheme.bodyLarge?.color, 
                                  fontSize: 14, 
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                )
                              ),
                              iconColor: theme.primaryColor,
                              collapsedIconColor: theme.primaryColor,
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
                        ],
                      ),
                    ] else ...[
                      _buildGlassCard(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                'Архив встреч пуст',
                                style: GoogleFonts.montserrat(
                                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
        
              const SizedBox(height: 16),
        
              // 🆕 📂 Архив заявок
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_archivedResponses.isNotEmpty) ...[
                      _buildGlassCard(
                        children: [
                          Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: Text(
                                'АРХИВ ЗАЯВОК', 
                                style: GoogleFonts.montserrat(
                                  color: theme.textTheme.bodyLarge?.color, 
                                  fontSize: 14, 
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                )
                              ),
                              iconColor: theme.primaryColor,
                              collapsedIconColor: theme.primaryColor,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
                                  child: Column(
                                    children: _archivedResponses
                                        .map((r) => _buildArchivedResponseCard(r))
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

  // 📦 Карточка архивной встречи
  Widget _buildArchiveMeetingCard(Map<String, dynamic> meeting) {
    final theme = Theme.of(context);
    final isCancelled = meeting['status'] == 'cancelled';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color?.withValues(alpha: 0.5),
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
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), 
                    fontSize: 14, 
                    fontWeight: FontWeight.w500,
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  meeting['location'] ?? '',
                  style: GoogleFonts.montserrat(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isCancelled ? Colors.redAccent.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCancelled ? Colors.redAccent.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3),
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

  Widget _buildArchivedResponseCard(Map<String, dynamic> response) {
    final theme = Theme.of(context);
    final meeting = response['meeting'];
    final meetingTitle = meeting?['title'] ?? 'Встреча';
    final meetingDate = meeting?['meeting_date'];
    final meetingTime = meeting?['meeting_time'];
    final status = response['status'] ?? 'cancelled';
    final isRejected = status == 'rejected';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color?.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meetingTitle,
                  style: GoogleFonts.montserrat(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), 
                    fontSize: 14, 
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (meetingDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    meeting?['location'] ?? '',
                    style: GoogleFonts.montserrat(
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isRejected ? Colors.redAccent.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isRejected ? Colors.redAccent.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              isRejected ? 'Отклонена' : 'Отменена',
              style: GoogleFonts.montserrat(
                color: isRejected ? Colors.redAccent : Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getFormattedDateTime(String dateStr, String? timeStr) {
    final meetingDate = DateTime.parse(dateStr);
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));

    final isToday = meetingDate.year == today.year &&
                    meetingDate.month == today.month &&
                    meetingDate.day == today.day;

    final isTomorrow = meetingDate.year == tomorrow.year &&
                       meetingDate.month == tomorrow.month &&
                       meetingDate.day == tomorrow.day;

    if (timeStr == null || timeStr.isEmpty) {
      if (isToday) return 'Сегодня';
      if (isTomorrow) return 'Завтра';
      
      const months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
      return '${meetingDate.day} ${months[meetingDate.month - 1]}';
    }

    if (isToday) return 'Сегодня в $timeStr';
    if (isTomorrow) return 'Завтра в $timeStr';

    const months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return '${meetingDate.day} ${months[meetingDate.month - 1]}, $timeStr';
  }

  bool _isArchivedMeeting(Map<String, dynamic> meeting) {
    final status = meeting['status'];
    final dateStr = meeting['meeting_date'];
    
    if (status == 'cancelled') return true;
    
    if (status == 'confirmed' && dateStr != null) {
      try {
        final meetingDate = DateTime.parse(dateStr);
        final today = DateTime.now();
        return meetingDate.year < today.year ||
               (meetingDate.year == today.year && meetingDate.month < today.month) ||
               (meetingDate.year == today.year && meetingDate.month == today.month && meetingDate.day < today.day);
      } catch (e) {
        return false;
      }
    }
    
    return false;
  }

  bool _hasAnyNewProfileFields() {
    return _profile?['height'] != null ||
           _profile?['weight'] != null ||
           _profile?['body_type'] != null ||
           _profile?['alcohol_attitude'] != null ||
           _profile?['smoking_attitude'] != null ||
           _profile?['marital_status'] != null ||
           _profile?['has_children'] != null;
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

  // 🆕 Карточка верификации (с размытием)
  Widget _buildVerificationCard() {
    final theme = Theme.of(context);
    final isVerified = _profile?['is_verified'] ?? false;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const VerificationScreen(),
          ),
        ).then((_) => loadProfile());
      },
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isVerified 
                  ? theme.primaryColor.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isVerified ? theme.primaryColor : theme.primaryColor.withValues(alpha: 0.3),
                width: isVerified ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isVerified ? Icons.verified : Icons.verified_outlined,
                    color: theme.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVerified ? 'ВЕРИФИЦИРОВАНЫ' : 'ПОЛУЧИТЬ ВЕРИФИКАЦИЮ',
                        style: GoogleFonts.montserrat(
                          color: theme.primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isVerified 
                            ? 'Золотая галочка доверия активна' 
                            : 'Повысьте доверие к своему профилю',
                        style: GoogleFonts.montserrat(
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: theme.primaryColor, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}