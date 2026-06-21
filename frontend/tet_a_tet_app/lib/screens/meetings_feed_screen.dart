import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/app_background.dart';
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
  
  // 🆕 Параметры фильтра по возрасту
  int? _minAge;
  int? _maxAge;

  String? _selectedGender;
  String? _userGender;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

    // 🆕 Загружаем профиль и ставим фильтр по умолчанию
  Future<void> _loadUserProfile() async {
    final profile = await _api.getProfile();
    if (mounted && profile != null) {
      final gender = profile['gender'] as String?;
      setState(() {
        _userGender = gender;
        // 🆕 Магия: если фильтр ещё не выбран, ставим противоположный пол!
        if (_selectedGender == null) {
          if (gender == 'male') {
            _selectedGender = 'female';
          } else if (gender == 'female') {
            _selectedGender = 'male';
          }
        }
      });
      // 🆕 Теперь, когда пол известен, загружаем правильную ленту
      _loadMeetings();
    }
  }

  // 🆕 Обновляем метод загрузки с параметрами фильтра
  Future<void> _loadMeetings() async {
    setState(() => _isLoading = true);
    final meetings = await _api.getActiveMeetings(minAge: _minAge, maxAge: _maxAge, gender: _selectedGender);
    setState(() {
      _meetings = meetings ?? [];
      _isLoading = false;
    });
  }

  // 🆕 Показываем красивый bottom sheet с фильтрами (один range slider!)
  void _showFilterSheet() {
    final theme = Theme.of(context);
    int tempMinAge = _minAge ?? 18;
    int tempMaxAge = _maxAge ?? 80;
    String? tempGender = _selectedGender;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: theme.primaryColor.withValues(alpha: 0.3)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ФИЛЬТРЫ',
                        style: GoogleFonts.montserrat(
                          color: theme.primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  Text(
                    'КТО ТЕБЯ ИНТЕРЕСУЕТ?',
                    style: GoogleFonts.montserrat(
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildGenderButton('all', 'Все', Icons.transgender, tempGender, () {
                        setState(() => tempGender = null);
                      }),
                      const SizedBox(width: 12),
                      _buildGenderButton('male', 'Мужчины', Icons.male, tempGender, () {
                        setState(() => tempGender = 'male');
                      }),
                      const SizedBox(width: 12),
                      _buildGenderButton('female', 'Женщины', Icons.female, tempGender, () {
                        setState(() => tempGender = 'female');
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  Text(
                    'ВОЗРАСТНОЙ ДИАПАЗОН',
                    style: GoogleFonts.montserrat(
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '$tempMinAge — $tempMaxAge лет',
                      style: GoogleFonts.montserrat(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: theme.primaryColor,
                      inactiveTrackColor: theme.primaryColor.withValues(alpha: 0.3),
                      thumbColor: theme.primaryColor,
                      overlayColor: theme.primaryColor.withValues(alpha: 0.2),
                      valueIndicatorColor: theme.primaryColor,
                      valueIndicatorTextStyle: GoogleFonts.montserrat(
                        color: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
                      rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
                    ),
                    child: RangeSlider(
                      values: RangeValues(tempMinAge.toDouble(), tempMaxAge.toDouble()),
                      min: 18,
                      max: 80,
                      divisions: 62,
                      labels: RangeLabels(tempMinAge.toString(), tempMaxAge.toString()),
                      onChanged: (values) {
                        setState(() {
                          tempMinAge = values.start.toInt();
                          tempMaxAge = values.end.toInt();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _minAge = null;
                              _maxAge = null;
                              _selectedGender = null;
                            });
                            Navigator.pop(context);
                            _loadMeetings();
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7) ?? Colors.grey),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text('СБРОСИТЬ', style: GoogleFonts.montserrat(
                            color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          )),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _minAge = tempMinAge == 18 ? null : tempMinAge;
                              _maxAge = tempMaxAge == 80 ? null : tempMaxAge;
                              _selectedGender = tempGender == 'all' ? null : tempGender;
                            });
                            Navigator.pop(context);
                            _loadMeetings();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text('ПРИМЕНИТЬ', style: GoogleFonts.montserrat(
                            color: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          )),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 🆕 Исправленный метод для кнопок пола
  Widget _buildGenderButton(String value, String label, IconData icon, String? selectedGender, VoidCallback onTap) {
    final theme = Theme.of(context);
    final isSelected = (value == 'all' && selectedGender == null) || selectedGender == value;
    
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.primaryColor.withValues(alpha: 0.2) : theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? theme.primaryColor : theme.dividerColor,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? theme.primaryColor : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  color: isSelected ? theme.primaryColor : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
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
                'ВСТРЕЧИ',
                style: GoogleFonts.montserrat(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  fontSize: 20,
                ),
              ),
              actions: [
                // 🆕 Кнопка фильтра с индикатором
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.tune,
                        color: (_minAge != null || _maxAge != null) 
                            ? theme.primaryColor 
                            : theme.iconTheme.color?.withValues(alpha: 0.7) ?? Colors.grey,
                      ),
                      onPressed: _showFilterSheet,
                    ),
                    if (_minAge != null || _maxAge != null)
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: theme.primaryColor),
                  onPressed: _loadMeetings,
                ),
              ],
            ),
          ),
        ),
      ),
      body: AppBackground(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
            : _meetings.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadMeetings,
                    color: theme.primaryColor,
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        MediaQuery.of(context).padding.top + kToolbarHeight + 16,
                        16,
                        MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 16,
                      ),
                      itemCount: _meetings.length,
                      itemBuilder: (context, index) {
                        return AnimatedMeetingCard(
                          index: index,
                          child: _buildMeetingCard(_meetings[index]),
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 80, color: theme.iconTheme.color?.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Пока нет активных встреч',
            style: GoogleFonts.montserrat(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Будь первым, кто предложит встречу!',
            style: GoogleFonts.montserrat(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingCard(Map<String, dynamic> meeting) {
    final theme = Theme.of(context);
    final formattedDate = _getFormattedDateTime(meeting['meeting_date'], meeting['meeting_time']);
    
    final isFemale = meeting['creator_gender'] == 'female' || meeting['creator_gender'] == 'ж';
    final IconData genderIcon = isFemale ? Icons.female : Icons.male;
    final Color genderColor = isFemale ? const Color(0xFFEC407A) : const Color(0xFF4FC3F7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: theme.primaryColor.withValues(alpha: 0.2),
        highlightColor: theme.primaryColor.withValues(alpha: 0.1),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MeetingDetailScreen(meeting: meeting)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.primaryColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(genderIcon, color: genderColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        meeting['title'],
                        style: GoogleFonts.montserrat(
                          color: theme.textTheme.bodyLarge?.color,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, color: theme.primaryColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        meeting['location'] ?? 'Место не указано',
                        style: GoogleFonts.montserrat(
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                          fontSize: 13,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, color: theme.primaryColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: GoogleFonts.montserrat(
                            color: theme.primaryColor,
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
      return _formatDate(dateStr);
    }

    if (isToday) return 'Сегодня в $timeStr';
    if (isTomorrow) return 'Завтра в $timeStr';
    
    return '${_formatDate(dateStr)}, $timeStr';
  }

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

// 🆕 Виджет для плавного появления карточек (выезжает снизу и проявляется)
class AnimatedMeetingCard extends StatefulWidget {
  final Widget child;
  final int index;

  const AnimatedMeetingCard({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  State<AnimatedMeetingCard> createState() => _AnimatedMeetingCardState();
}

class _AnimatedMeetingCardState extends State<AnimatedMeetingCard> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );

    // Плавное появление прозрачности
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    
    // Мягкий выезд снизу вверх
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15), 
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // 🎯 Магия задержки (stagger effect)! Каждая следующая карточка появляется чуть позже
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}