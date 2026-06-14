import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/background_pattern.dart';
import 'chat_screen.dart';
import 'user_profile_screen.dart';
import 'my_meetings_screen.dart';

class MeetingDetailScreen extends StatelessWidget {
  final Map<String, dynamic> meeting;
  final ValueNotifier<int> _refreshKey = ValueNotifier<int>(0);
  MeetingDetailScreen({super.key, required this.meeting});

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
              backgroundColor: Colors.black.withValues(alpha: 0.3),
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
                child: GestureDetector(
                    onTap: () {
                      if (meeting['creator_id'] != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfileScreen(userId: meeting['creator_id'].toString()),
                          ),
                        );
                      }
                    },                  
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        AspectRatio(
                          aspectRatio: 1.0, 
                          child: meeting['creator_avatar_url'] != null
                              ? CachedNetworkImage(
                                  imageUrl: '${ApiService.baseUrl}${meeting['creator_avatar_url']}',
                                  fit: BoxFit.cover,
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
                        Container(
                          height: 90,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.95),
                                Colors.black.withValues(alpha: 0.6),
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
              ),

              const SizedBox(height: 24),

              // 📌 Название встречи
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

              // 📅 Дата, время и место
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
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
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

              _buildResponsesSection(meeting['id'].toString()),

              // 💌 УМНАЯ КНОПКА ОТКЛИКА (скрывается для создателя и тех, кто уже откликнулся)
              FutureBuilder<Map<String, dynamic>?>(
                future: ApiService().getProfile(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }
                  
                  final currentUserId = snapshot.data?['id']?.toString();
                  final isCreator = meeting['creator_id']?.toString() == currentUserId;
                  final hasResponded = meeting['has_responded'] == true;

                  print('🔍 [ОТКЛИК] currentUserId: $currentUserId, creator_id: ${meeting['creator_id']}, has_responded: ${meeting['has_responded']}');

                  // 🛡️ Если это создатель встречи ИЛИ он уже откликнулся — скрываем кнопку!
                  if (isCreator || hasResponded) {
                    return const SizedBox(height: 20);
                  }

                  // Иначе показываем кнопку отклика
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                          shadowColor: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                        ),
                        onPressed: () async {
                          final api = ApiService();
                          final TextEditingController msgController = TextEditingController();
                          final result = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF1E1E1E),
                              title: Text('Откликнуться на встречу', style: GoogleFonts.montserrat(color: Colors.white)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Хочешь оставить сообщение автору?', style: GoogleFonts.montserrat(color: Colors.grey)),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: msgController,
                                    maxLines: 3,
                                    style: GoogleFonts.montserrat(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: 'Например: Привет! С удовольствием составлю компанию 🍷',
                                      hintStyle: GoogleFonts.montserrat(color: Colors.grey),
                                      filled: true,
                                      fillColor: Colors.black.withValues(alpha: 0.3),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Отмена', style: GoogleFonts.montserrat(color: Colors.grey))),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text('Отправить', style: GoogleFonts.montserrat(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );

                          if (result == true) {
                            final success = await api.createResponse(meeting['id'].toString(), msgController.text.trim());
                            
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success ? 'Твой отклик отправлен! Жди решения 💕' : 'Не удалось отправить отклик'),
                                  backgroundColor: success ? Colors.green : Colors.redAccent,
                                ),
                              );
                              
                              // 🆕 Если отклик успешен, плавно переходим на экран "Мои встречи"
                              if (success) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => const MyMeetingsScreen()),
                                );
                              }
                            }
                          }
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
                  );
                },
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

  // 📋 Секция с откликами (видна только автору)
  Widget _buildResponsesSection(String meetingId) {
    return ValueListenableBuilder<int>(
      valueListenable: _refreshKey,
      builder: (context, value, child) {
        return FutureBuilder<List<dynamic>?>(
          future: ApiService().getMeetingResponses(meetingId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }
            
            if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
              return const SizedBox.shrink(); 
            }
            
            final responses = snapshot.data!;

            // 🆕 Помечаем отклики как прочитанные (только если они есть и мы автор)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ApiService().markResponsesAsRead(meetingId);
            });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'ОТКЛИКИ (${responses.length})',
                    style: GoogleFonts.montserrat(
                      color: const Color(0xFFD4AF37),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...responses.map((resp) => _buildResponseCard(context, resp)),
              ],
            );
          },
        );
      },
    );
  }

  // 🃏 Карточка откликнувшегося
  Widget _buildResponseCard(BuildContext context, Map<String, dynamic> resp) {
    final username = resp['responder_username'] ?? 'Аноним';
    final age = resp['responder_age'];
    final nameWithAge = age != null ? '$username, $age' : username;
    final message = resp['response_message'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(
                      userId: resp['user_id'].toString(),
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                      child: const Icon(Icons.person, color: Color(0xFFD4AF37)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        nameWithAge,
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                          decorationColor: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    // 🆕 Умный статус отклика (учитываем все возможные статусы)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getResponseStatusColor(resp['status']).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getResponseStatusText(resp['status']),
                        style: GoogleFonts.montserrat(
                          color: _getResponseStatusColor(resp['status']),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            if (message != null && message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  message,
                  style: GoogleFonts.montserrat(
                    color: Colors.white70,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            
            // 👇 НИЖНЯЯ ЧАСТЬ: Кнопки действий
            // 👇 НИЖНЯЯ ЧАСТЬ: Кнопки действий
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 🆕 Показываем кнопки "Отклонить" и "Принять" ТОЛЬКО если статус "pending"
                if (resp['status'] == 'pending') ...[
                  TextButton.icon(
                    onPressed: () async {
                      final success = await ApiService().updateResponseStatus(resp['id'].toString(), 'rejected');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Отклик отклонен' : 'Не удалось отклонить'),
                            backgroundColor: success ? Colors.redAccent : Colors.grey,
                          ),
                        );
                        if (success) {
                          _refreshKey.value++; // 🆕 Магическое обновление списка!
                        }
                      }
                    },
                    icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                    label: const Text('Отклонить', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final success = await ApiService().updateResponseStatus(resp['id'].toString(), 'accepted');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Отклик принят! Теперь можно написать 💬' : 'Не удалось принять'),
                            backgroundColor: success ? Colors.green : Colors.grey,
                          ),
                        );
                        if (success) {
                          _refreshKey.value++; // 🆕 Магическое обновление списка!
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Принять', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                ],
                
                // 💬 Кнопка "Написать" (видна всегда, чтобы автор мог начать чат)
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          meetingId: meeting['id'].toString(),
                          meetingTitle: meeting['title'],
                          opponentName: resp['responder_username'] ?? 'Аноним',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFFD4AF37), size: 22),
                  tooltip: 'Написать',
                ),
              ],
            ),
          ],
        ),
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
      final date = DateTime.parse(dateStr);
      return '${date.day} ${months[date.month - 1]}';
    }

    if (isToday) return 'Сегодня в $timeStr';
    if (isTomorrow) return 'Завтра в $timeStr';
    
    final date = DateTime.parse(dateStr);
    const months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return '${date.day} ${months[date.month - 1]}, $timeStr';
  }

  // 🎨 Цвета для статусов отклика
  Color _getResponseStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.green;
      case 'rejected': return Colors.redAccent;
      case 'confirmed': return Colors.blue;
      case 'cancelled': return Colors.grey;
      default: return Colors.grey;
    }
  }

  // 📝 Текст для статусов отклика
  String _getResponseStatusText(String status) {
    switch (status) {
      case 'pending': return 'Ждёт';
      case 'accepted': return 'Принят';
      case 'rejected': return 'Отклонён';
      case 'confirmed': return 'Подтверждён';
      case 'cancelled': return 'Отменён';
      default: return 'Неизвестно';
    }
  }

}