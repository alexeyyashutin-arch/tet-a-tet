import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/background_pattern.dart';

class MeetingDetailScreen extends StatelessWidget {
  final Map<String, dynamic> meeting;

  const MeetingDetailScreen({super.key, required this.meeting});

  @override
  Widget build(BuildContext context) {
    final username = meeting['creator_username'] ?? 'Аноним';
    final age = meeting['creator_age'];
    final nameWithAge = age != null ? '$username, $age' : username;
    final formattedDate = _getFormattedDateTime(meeting['meeting_date'], meeting['meeting_time']);
    
    // 🚺 Определяем пол и иконку
    final isFemale = meeting['creator_gender'] == 'female' || meeting['creator_gender'] == 'ж';
    final IconData genderIcon = isFemale ? Icons.female : Icons.male;
    final Color genderColor = isFemale ? const Color(0xFFEC407A) : const Color(0xFF4FC3F7);

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
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'ПОДРОБНОСТИ',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
      body: BackgroundPattern(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            0, // Сверху 0, так как аватарка будет прилегать к AppBar
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
                        child: meeting['creator_avatar_url'] != null // В meeting_detail_screen здесь будет meeting['creator_avatar_url']
                            ? CachedNetworkImage(
                                imageUrl: '${ApiService.baseUrl}${meeting['creator_avatar_url']}', // Или meeting['creator_avatar_url']
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

              // 📌 Название встречи (с отступом по бокам)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  meeting['title'],
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 📅 Дата, время и место (с отступом по бокам)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.calendar_today, formattedDate),
                    if (meeting['location'] != null && meeting['location'].toString().isNotEmpty)
                      _buildInfoRow(Icons.location_on, meeting['location']),
                  ],
                ),
              ),

              // 📝 Описание
              if (meeting['description'] != null && meeting['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ОПИСАНИЕ',
                        style: GoogleFonts.montserrat(
                          color: const Color(0xFFD4AF37),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        meeting['description'],
                        style: GoogleFonts.montserrat(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 💫 Пожелания
              if (meeting['partner_wishes'] != null && meeting['partner_wishes'].toString().isNotEmpty) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ПОЖЕЛАНИЯ К СПУТНИЦЕ',
                        style: GoogleFonts.montserrat(
                          color: const Color(0xFFD4AF37),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                        ),
                        child: Text(
                          meeting['partner_wishes'],
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // 💌 Кнопка отклика
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: const Color(0xFFD4AF37).withOpacity(0.4),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Твой отклик отправлен для $username! Жди ответа 💕'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    child: Text(
                      'ОТКЛИКНУТЬСЯ НА ВСТРЕЧУ',
                      style: GoogleFonts.montserrat(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFD4AF37), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.montserrat(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getFormattedDateTime(String dateStr, String timeStr) {
    final meetingDate = DateTime.parse(dateStr);
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));

    final isToday = meetingDate.year == today.year && 
                    meetingDate.month == today.month && 
                    meetingDate.day == today.day;
                    
    final isTomorrow = meetingDate.year == tomorrow.year && 
                       meetingDate.month == tomorrow.month && 
                       meetingDate.day == tomorrow.day;

    if (isToday) return 'Сегодня в $timeStr';
    if (isTomorrow) return 'Завтра в $timeStr';
    
    final date = DateTime.parse(dateStr);
    const months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return '${date.day} ${months[date.month - 1]}, $timeStr';
  }
}