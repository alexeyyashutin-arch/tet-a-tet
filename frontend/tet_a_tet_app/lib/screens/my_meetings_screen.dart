import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/background_pattern.dart';
import 'create_meeting_screen.dart';
import 'meeting_detail_screen.dart';
import 'chat_screen.dart';

class MyMeetingsScreen extends StatefulWidget {
  const MyMeetingsScreen({super.key});

  @override
  State<MyMeetingsScreen> createState() => _MyMeetingsScreenState();
}

class _MyMeetingsScreenState extends State<MyMeetingsScreen> {
  final _api = ApiService();
  List<dynamic> _myMeetings = [];
  List<dynamic> _myResponses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final meetings = await _api.getMyMeetings();
    final responses = await _api.getMyResponses();
    
    if (mounted) {
      setState(() {
        _myMeetings = meetings ?? [];
        _myResponses = responses ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              title: Text(
                'МОИ ВСТРЕЧИ',
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
            : RefreshIndicator(
                onRefresh: _loadData,
                color: const Color(0xFFD4AF37),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    MediaQuery.of(context).padding.top + kToolbarHeight + 16,
                    16,
                    MediaQuery.of(context).padding.bottom + 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 📅 Секция: Активные встречи
                      Text(
                        'АКТИВНЫЕ ВСТРЕЧИ',
                        style: GoogleFonts.montserrat(
                          color: const Color(0xFFD4AF37),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      if (_myMeetings.where((m) => m['status'] == 'active').isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                          ),
                          child: Center(
                            child: Text(
                              'У вас пока нет активных встреч',
                              style: GoogleFonts.montserrat(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        ..._myMeetings
                            .where((m) => m['status'] == 'active')
                            .map((m) => _buildActiveMeetingCard(m))
                            ,
                      
                      const SizedBox(height: 32),
                      
                      // 💌 Секция: Мои заявки
                      Text(
                        'МОИ ЗАЯВКИ',
                        style: GoogleFonts.montserrat(
                          color: const Color(0xFFD4AF37),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      if (_myResponses.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                          ),
                          child: Center(
                            child: Text(
                              'Вы пока не откликались на встречи',
                              style: GoogleFonts.montserrat(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        ..._myResponses
                            .where((r) => r['status'] == 'pending' || r['status'] == 'accepted' || r['status'] == 'confirmed')
                            .map((r) => _buildResponseCard(r))
                            ,
                    ],
                  ),
                ),
              ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0, right: 16.0),
        child: FloatingActionButton(
          backgroundColor: const Color(0xFFD4AF37),
          elevation: 8,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateMeetingScreen()),
            ).then((_) => _loadData());
          },
          child: const Icon(Icons.add, color: Colors.black),
        ),
      ),
    );
  }

  // 🃏 Карточка созданной встречи (теперь кликабельная и с бейджиком откликов!)
  Widget _buildActiveMeetingCard(Map<String, dynamic> meeting) {
    final meetingId = meeting['id'];
    final title = meeting['title'];
    final dateStr = meeting['meeting_date'];
    final timeStr = meeting['meeting_time'];
    final location = meeting['location'];
    final status = meeting['status'];
    final responsesCount = meeting['responses_count'] ?? 0;

    final formattedDate = _getFormattedDateTime(dateStr, timeStr);
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);
    final statusIcon = _getStatusIcon(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MeetingDetailScreen(meeting: meeting),
                ),
              ).then((_) => _loadData());
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (responsesCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_outline, color: Color(0xFFD4AF37), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                responsesCount.toString(),
                                style: GoogleFonts.montserrat(
                                  color: const Color(0xFFD4AF37),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, color: statusColor, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              statusText,
                              style: GoogleFonts.montserrat(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Color(0xFFD4AF37), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          formattedDate,
                          style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  if (location != null && location.toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFFD4AF37), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            location,
                            style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'ПОДРОБНЕЕ И ОТКЛИКИ →',
                      style: GoogleFonts.montserrat(
                        color: const Color(0xFFD4AF37),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
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

  // 💌 Карточка заявки на чужую встречу (со стеклом!)
  Widget _buildResponseCard(Map<String, dynamic> response) {
    final status = response['status'] ?? 'pending';
    final meetingId = response['meeting_id'];
    final meetingTitle = response['meeting_title'] ?? 'Название встречи';
    final meeting = response['meeting'];
    
    final meetingDate = meeting?['meeting_date'];
    final meetingTime = meeting?['meeting_time'];
    final meetingLocation = meeting?['location'];
    final hasMessages = meeting?['has_messages'] ?? false;
    
    String formattedDate = 'Дата уточняется';
    if (meetingDate != null) {
      formattedDate = _getFormattedDateTime(meetingDate, meetingTime);
    }
    
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);
    final statusIcon = _getStatusIcon(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRect( 
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4), 
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        meetingTitle,
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (hasMessages) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.chat_bubble, color: Color(0xFFD4AF37), size: 20),
                    ],
                    // 🆕 Показываем верхний бейджик ТОЛЬКО если статус НЕ 'confirmed'
                    // (потому что для 'confirmed' внизу уже есть большая красивая плашка "ВСТРЕЧА ПОДТВЕРЖДЕНА")
                    if (status != 'confirmed') ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, color: statusColor, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              statusText,
                              style: GoogleFonts.montserrat(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Color(0xFFD4AF37), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        formattedDate,
                        style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                
                if (meetingLocation != null && meetingLocation.toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFFD4AF37), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          meetingLocation,
                          style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
                
                const SizedBox(height: 12),
                
                // Кнопка подтверждения встречи (появляется, если автор принял заявку)
                if (status == 'accepted') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final success = await ApiService().updateResponseStatus(response['id'].toString(), 'confirmed');
                        if (mounted && success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Встреча подтверждена! Она исчезнет из общей ленты '), 
                              backgroundColor: Colors.green,
                            ),
                          );
                          _loadData();
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Не удалось подтвердить'), backgroundColor: Colors.redAccent),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: Text(
                        'ПОДТВЕРДИТЬ ВСТРЕЧУ', 
                        style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ] else if (status == 'confirmed') ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'ВСТРЕЧА ПОДТВЕРЖДЕНА', 
                          style: GoogleFonts.montserrat(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // 💬 Кнопка перехода в чат (ПОЯВЛЯЕТСЯ ТОЛЬКО если создатель уже начал чат)
                if (hasMessages == true) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              meetingId: meetingId.toString(),
                              meetingTitle: meetingTitle,
                              opponentName: response['responder_username'] ?? 'Собеседник',
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.chat, size: 20),
                      label: Text(
                        'ПЕРЕЙТИ В ЧАТ',
                        style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
                
                // 🆕 КНОПКА ОТМЕНЫ ЗАЯВКИ (видна ТОЛЬКО если статус "pending")
                if (status == 'pending') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        // Спрашиваем подтверждение, чтобы не нажать случайно
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF1E1E1E),
                            title: Text('Отменить заявку?', style: GoogleFonts.montserrat(color: Colors.white)),
                            content: Text('Вы уверены, что хотите отменить свою заявку на эту встречу?', style: GoogleFonts.montserrat(color: Colors.grey)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false), 
                                child: Text('Нет', style: GoogleFonts.montserrat(color: Colors.grey))
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true), 
                                child: Text('Да, отменить', style: GoogleFonts.montserrat(color: Colors.redAccent, fontWeight: FontWeight.bold))
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          final success = await ApiService().cancelResponse(response['id'].toString());
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success ? 'Заявка успешно отменена' : 'Не удалось отменить заявку'),
                                backgroundColor: success ? Colors.green : Colors.redAccent,
                              ),
                            );
                            if (success) {
                              _loadData(); // 🆕 Обновляем список, чтобы карточка изменила статус
                            }
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 20),
                      label: Text(
                        'ОТМЕНИТЬ ЗАЯВКУ', 
                        style: GoogleFonts.montserrat(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      if (meeting != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MeetingDetailScreen(meeting: meeting),
                          ),
                        );
                      }
                    },
                    child: Text(
                      'ПОДРОБНЕЕ',
                      style: GoogleFonts.montserrat(
                        color: const Color(0xFFD4AF37),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 📅 Форматируем дату и время для красивого отображения
  String _getFormattedDateTime(String? dateStr, String? timeStr) {
    if (dateStr == null) return 'Дата уточняется';
    try {
      final date = DateTime.parse(dateStr);
      final day = date.day;
      final month = _getMonthName(date.month);
      final time = timeStr != null ? ' в $timeStr' : '';
      return '$day $month$time';
    } catch (e) {
      return 'Дата уточняется';
    }
  }

  // 🗓️ Вспомогательный метод для названия месяца
  String _getMonthName(int month) {
    const months = [
      '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    return months[month];
  }

  // 🎨 Цвета для статусов
  Color _getStatusColor(String status) {
    switch (status) {
      case 'active': return Colors.green;
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.green;
      case 'rejected': return Colors.redAccent;
      case 'confirmed': return Colors.blue;
      case 'cancelled': return Colors.grey;
      default: return Colors.grey;
    }
  }

  // 📝 Текст для статусов
  String _getStatusText(String status) {
    switch (status) {
      case 'active': return 'Активна';
      case 'pending': return 'В ожидании';
      case 'accepted': return 'Принята';
      case 'rejected': return 'Отклонена';
      case 'confirmed': return 'Подтверждена';
      case 'cancelled': return 'Отменена';
      default: return 'Неизвестно';
    }
  }

  // 🎯 Иконки для статусов
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'active': return Icons.event_available;
      case 'pending': return Icons.access_time;
      case 'accepted': return Icons.check_circle_outline;
      case 'rejected': return Icons.cancel_outlined;
      case 'confirmed': return Icons.verified;
      case 'cancelled': return Icons.block;
      default: return Icons.help_outline;
    }
  }
}