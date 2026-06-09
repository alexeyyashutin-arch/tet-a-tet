import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/background_pattern.dart';
import 'create_meeting_screen.dart';
import 'meeting_detail_screen.dart';

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
    
    // 🆕 Временно загружаем только созданные встречи
    final meetings = await _api.getMyMeetings();
    // TODO: Добавить getMyResponses() когда будет готов бэкенд для откликов
    
    if (mounted) {
      setState(() {
        _myMeetings = meetings ?? [];
        _myResponses = []; // Пока пустой список
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
              backgroundColor: Colors.black.withOpacity(0.3),
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
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
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
                            .toList(),
                      
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
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
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
                            .map((r) => _buildResponseCard(r))
                            .toList(),
                    ],
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFD4AF37),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateMeetingScreen()),
          ).then((_) => _loadData());
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

   // 🃏 Карточка активной встречи (со стеклом!)
  Widget _buildActiveMeetingCard(Map<String, dynamic> meeting) {
    final formattedDate = _getFormattedDateTime(meeting['meeting_date'], meeting['meeting_time']);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRect( // 🆕 Обрезаем размытие по краям
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4), // 🆕 Размытие фона
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meeting['title'],
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
                const SizedBox(height: 8),
                if (meeting['location'] != null && meeting['location'].toString().isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFFD4AF37), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          meeting['location'],
                          style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
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
                        _loadData();
                      }
                    },
                    icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 18),
                    label: const Text('Отменить', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 💌 Карточка заявки на чужую встречу (со стеклом!)
  Widget _buildResponseCard(Map<String, dynamic> response) {
    final meeting = response['meeting'];
    final status = response['status'];
    final formattedDate = _getFormattedDateTime(meeting['meeting_date'], meeting['meeting_time']);
    
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);
    final statusIcon = _getStatusIcon(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRect( // 🆕 Обрезаем размытие
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4), // 🆕 Размытие фона
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        meeting['title'],
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.5)),
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
                if (meeting['location'] != null && meeting['location'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFFD4AF37), size: 16),
                      const SizedBox(width: 8),
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
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MeetingDetailScreen(meeting: meeting),
                        ),
                      );
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.redAccent;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'accepted':
        return 'Принята';
      case 'rejected':
        return 'Отклонена';
      case 'pending':
      default:
        return 'В ожидании';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.hourglass_empty;
    }
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

    const months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return '${meetingDate.day} ${months[meetingDate.month - 1]}, $timeStr';
  }
}