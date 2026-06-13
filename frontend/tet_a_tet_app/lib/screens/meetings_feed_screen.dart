import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/background_pattern.dart';
import 'meeting_detail_screen.dart';
import 'dart:ui';

class MeetingsFeedScreen extends StatefulWidget {
  const MeetingsFeedScreen({super.key});

  @override
  State<MeetingsFeedScreen> createState() => _MeetingsFeedScreenState();
}

class _MeetingsFeedScreenState extends State<MeetingsFeedScreen> {
  final _api = ApiService();
  List<dynamic> _meetings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMeetings();
  }

  Future<void> _loadMeetings() async {
    setState(() => _isLoading = true);
    final meetings = await _api.getActiveMeetings();
    setState(() {
      _meetings = meetings ?? [];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Уже есть из-за нижнего меню
      extendBodyBehindAppBar: true, // 🆕 ВАЖНО! Позволяет контенту залезать под AppBar
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // 🆕 Blur-эффект
            child: AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.2), // 🆕 Полупрозрачный
              elevation: 0,
              centerTitle: true,
              title: Text(
                'ВСТРЕЧИ',
                style: GoogleFonts.montserrat(
                  color: const Color(0xFFD4AF37),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  fontSize: 20,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFFD4AF37)),
                  onPressed: _loadMeetings,
                ),
              ],
            ),
          ),
        ),
      ),
      body: BackgroundPattern(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
            : _meetings.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadMeetings,
                    color: const Color(0xFFD4AF37),
                    child: ListView.builder(
                      // padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 16), // 🆕 Добавляем отступ сверху
                      padding: EdgeInsets.fromLTRB(
                        16, // Слева
                        MediaQuery.of(context).padding.top + kToolbarHeight + 16, // Сверху: статус-бар + высота AppBar + воздух
                        16, // Справа
                        MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 16, // Снизу: home-индикатор + высота меню + воздух
                      ),
                      itemCount: _meetings.length,
                      itemBuilder: (context, index) {
                        return _buildMeetingCard(_meetings[index]);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_busy, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Пока нет активных встреч',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Будь первым, кто предложит встречу!',
            style: GoogleFonts.montserrat(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingCard(Map<String, dynamic> meeting) {
    // 🆕 Используем новый умный метод форматирования
    final formattedDate = _getFormattedDateTime(meeting['meeting_date'], meeting['meeting_time']);
    
    // 🚺 Определяем пол и иконку
    final isFemale = meeting['creator_gender'] == 'female' || meeting['creator_gender'] == 'ж';
    final IconData genderIcon = isFemale ? Icons.female : Icons.male;
    final Color genderColor = isFemale ? const Color(0xFFEC407A) : const Color(0xFF4FC3F7);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MeetingDetailScreen(meeting: meeting)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.5), 
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 📌 СТРОКА 1: Значок пола | Название встречи (на всю ширину)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(genderIcon, color: genderColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          meeting['title'],
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                          maxLines: 2, // Позволяем названию перенестись, если оно длинное
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 📌 СТРОКА 2: Место встречи (слева) | Дата и время (справа)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFFD4AF37), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          meeting['location'] ?? 'Место не указано',
                          style: GoogleFonts.montserrat(
                            color: Colors.white70, 
                            fontSize: 13,
                            height: 1.3,
                          ),
                          maxLines: 2, 
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 📅 Дата и время справа
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, color: Color(0xFFD4AF37), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: GoogleFonts.montserrat(
                              color: const Color(0xFFD4AF37),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🆕 Умное форматирование даты (теперь с поддержкой пустого времени!)
  String _getFormattedDateTime(String dateStr, String? timeStr) {
    final meetingDate = DateTime.parse(dateStr);
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));

    // Сравниваем только дату (год, месяц, день)
    final isToday = meetingDate.year == today.year && 
                    meetingDate.month == today.month && 
                    meetingDate.day == today.day;
                    
    final isTomorrow = meetingDate.year == tomorrow.year && 
                       meetingDate.month == tomorrow.month && 
                       meetingDate.day == tomorrow.day;

    // 🆕 Если время не указано, показываем только дату
    if (timeStr == null || timeStr.isEmpty) {
      if (isToday) return 'Сегодня';
      if (isTomorrow) return 'Завтра';
      return _formatDate(dateStr);
    }

    // Если время есть, показываем как раньше
    if (isToday) return 'Сегодня в $timeStr';
    if (isTomorrow) return 'Завтра в $timeStr';
    
    // Если день другой, используем старый метод
    return '${_formatDate(dateStr)}, $timeStr';
  }

  // Старый метод оставляем дляfallback
  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    const months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return '${date.day} ${months[date.month - 1]}';
  }

  String _getFinanceText(String finance) {
    switch (finance) {
      case 'self':
        return 'Плачу сам';
      case 'split':
        return 'Платим поровну';
      case 'partner':
        return 'Платит партнёр';
      case 'none':
        return 'Бесплатно';
      default:
        return finance;
    }
  }

}