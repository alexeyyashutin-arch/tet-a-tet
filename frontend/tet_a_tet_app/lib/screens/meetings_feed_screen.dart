import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/app_background.dart';
import 'meeting_detail_screen.dart';
import 'premium_screen.dart';
import 'create_meeting_screen.dart';
import 'dart:ui';
import '../widgets/glass_card.dart';

class MeetingsFeedScreen extends StatefulWidget {
  const MeetingsFeedScreen({super.key});

  @override
  State<MeetingsFeedScreen> createState() => _MeetingsFeedScreenState();
}

class _MeetingsFeedScreenState extends State<MeetingsFeedScreen> {
  final _api = ApiService();
  List<dynamic> _meetings = [];
  bool _isLoading = true;
  
  int? _minAge;
  int? _maxAge;
  String? _selectedGender;
  String? _selectedMaritalStatus;
  String? _userGender;

  // 🍓 Клубничка: переключатель обычные / взрослые встречи
  bool _adultOnly = false;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final profile = await _api.getProfile();
    if (mounted && profile != null) {
      final gender = profile['gender'] as String?;
      final isPremium = profile['is_premium'] == true;
      setState(() {
        _userGender = gender;
        _isPremium = isPremium;
        if (_selectedGender == null) {
          if (gender == 'male') {
            _selectedGender = 'female';
          } else if (gender == 'female') {
            _selectedGender = 'male';
          }
        }
        if (!isPremium) {
          _adultOnly = false;
        }
      });
      _loadMeetings();
    }
  }

  Future<void> _loadMeetings() async {
    setState(() => _isLoading = true);
    final meetings = await _api.getActiveMeetings(
      minAge: _minAge,
      maxAge: _maxAge,
      gender: _selectedGender,
      adultOnly: _adultOnly,
      maritalStatus: _selectedMaritalStatus,
    );
    setState(() {
      _meetings = meetings ?? [];
      _isLoading = false;
    });
  }

  void _showFilterSheet() {
    final theme = Theme.of(context);
    int tempMinAge = _minAge ?? 18;
    int tempMaxAge = _maxAge ?? 80;
    String? tempGender = _selectedGender;
    String? tempMaritalStatus = _selectedMaritalStatus;
    bool tempAdultOnly = _adultOnly;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ФИЛЬТРЫ', style: GoogleFonts.montserrat(color: theme.primaryColor, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        IconButton(icon: Icon(Icons.close, color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7)), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('КТО ТЕБЯ ИНТЕРЕСУЕТ?', style: GoogleFonts.montserrat(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildGenderButton('all', 'Все', Icons.transgender, tempGender, () => setState(() => tempGender = null)),
                        const SizedBox(width: 12),
                        _buildGenderButton('male', 'Мужчины', Icons.male, tempGender, () => setState(() => tempGender = 'male')),
                        const SizedBox(width: 12),
                        _buildGenderButton('female', 'Женщины', Icons.female, tempGender, () => setState(() => tempGender = 'female')),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('ВОЗРАСТНОЙ ДИАПАЗОН', style: GoogleFonts.montserrat(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    const SizedBox(height: 8),
                    Center(child: Text('$tempMinAge — $tempMaxAge лет', style: GoogleFonts.montserrat(color: theme.textTheme.bodyLarge?.color, fontSize: 24, fontWeight: FontWeight.bold))),
                    const SizedBox(height: 16),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: theme.primaryColor,
                        inactiveTrackColor: theme.primaryColor.withValues(alpha: 0.3),
                        thumbColor: theme.primaryColor,
                        overlayColor: theme.primaryColor.withValues(alpha: 0.2),
                        valueIndicatorColor: theme.primaryColor,
                        rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
                        rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
                      ),
                      child: RangeSlider(
                        values: RangeValues(tempMinAge.toDouble(), tempMaxAge.toDouble()),
                        min: 18, max: 80, divisions: 62,
                        labels: RangeLabels(tempMinAge.toString(), tempMaxAge.toString()),
                        onChanged: (values) => setState(() { tempMinAge = values.start.toInt(); tempMaxAge = values.end.toInt(); }),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('СЕМЕЙНОЕ ПОЛОЖЕНИЕ', style: GoogleFonts.montserrat(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildGenderButton('all', 'Все', Icons.people, tempMaritalStatus, () => setState(() => tempMaritalStatus = null)),
                        const SizedBox(width: 12),
                        _buildGenderButton('Свободен', 'Свободен', Icons.favorite_border, tempMaritalStatus, () => setState(() => tempMaritalStatus = 'Свободен')),
                        const SizedBox(width: 12),
                        _buildGenderButton('В браке', 'В браке', Icons.circle, tempMaritalStatus, () => setState(() => tempMaritalStatus = 'В браке')),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 🍓 Чекбокс «Встречи с клубничкой» (только для премиум)
                    if (_isPremium)
                      CheckboxListTile(
                        value: tempAdultOnly,
                        onChanged: (val) => setState(() => tempAdultOnly = val ?? false),
                        title: Text('🍓 Встречи с клубничкой', style: GoogleFonts.montserrat(color: theme.textTheme.bodyLarge?.color, fontSize: 14)),
                        subtitle: Text('Показывать встречи 18+ в общей ленте', style: GoogleFonts.montserrat(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 12)),
                        activeColor: theme.primaryColor,
                        checkColor: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() { _minAge = null; _maxAge = null; _selectedGender = null; _selectedMaritalStatus = null; _adultOnly = false; });
                              Navigator.pop(context);
                              _loadMeetings();
                            },
                            style: OutlinedButton.styleFrom(side: BorderSide(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7) ?? Colors.grey), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                            child: Text('СБРОСИТЬ', style: GoogleFonts.montserrat(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.bold)),
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
                                _selectedMaritalStatus = tempMaritalStatus == 'all' ? null : tempMaritalStatus;
                                _adultOnly = tempAdultOnly;
                              });
                              Navigator.pop(context);
                              _loadMeetings();
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: theme.brightness == Brightness.dark ? Colors.black : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                            child: Text('ПРИМЕНИТЬ', style: GoogleFonts.montserrat(color: theme.brightness == Brightness.dark ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAdultTypeButton(String label, IconData icon, bool isAdult, bool selected, VoidCallback onTap) {
    final theme = Theme.of(context);
    final isSelected = isAdult == selected;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.primaryColor.withValues(alpha: 0.2) : theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? theme.primaryColor : theme.dividerColor, width: isSelected ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? theme.primaryColor : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), size: 24),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.montserrat(color: isSelected ? theme.primaryColor : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockedAdultButton(String label) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.dividerColor, width: 1)),
          child: Column(
            children: [
              Icon(Icons.lock, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4), size: 24),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.montserrat(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

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
            border: Border.all(color: isSelected ? theme.primaryColor : theme.dividerColor, width: isSelected ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? theme.primaryColor : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), size: 24),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.montserrat(color: isSelected ? theme.primaryColor : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.bold)),
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
              elevation: 0, centerTitle: true,
              title: Text('ВСТРЕЧИ', style: GoogleFonts.montserrat(color: theme.primaryColor, fontWeight: FontWeight.bold, letterSpacing: 2.0, fontSize: 20)),
              actions: [
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(Icons.tune, color: (_minAge != null || _maxAge != null || _adultOnly || _selectedMaritalStatus != null) ? theme.primaryColor : theme.iconTheme.color?.withValues(alpha: 0.7) ?? Colors.grey),
                      onPressed: _showFilterSheet,
                    ),
                    if (_minAge != null || _maxAge != null || _adultOnly || _selectedMaritalStatus != null)
                      Positioned(right: 12, top: 12, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: theme.primaryColor, shape: BoxShape.circle))),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CreateMeetingScreen()),
                      ).then((_) => _loadMeetings());
                    },
                    child: Icon(Icons.add, size: 20),
                  ),
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
                      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + kToolbarHeight + 16, 16, MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 16),
                      itemCount: _meetings.length,
                      itemBuilder: (context, index) => AnimatedMeetingCard(index: index, child: _buildMeetingCard(_meetings[index])),
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
          Text('Пока нет активных встреч', style: GoogleFonts.montserrat(color: theme.textTheme.bodyLarge?.color, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Будь первым, кто предложит встречу!', style: GoogleFonts.montserrat(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildMeetingCard(Map<String, dynamic> meeting) {
    final theme = Theme.of(context);
    final isFemale = meeting['creator_gender'] == 'female' || meeting['creator_gender'] == 'ж';
    final genderIcon = isFemale ? Icons.female : Icons.male;
    final genderColor = isFemale ? const Color(0xFFEC407A) : const Color(0xFF4FC3F7);
    final isAdult = meeting['is_adult'] == true;
    final creatorIsVerified = meeting['creator_is_verified'] == true;
    final creatorIsPremium = meeting['creator_is_premium'] == true;
    final daysLeft = _getDaysLeft(meeting['meeting_date']);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: theme.primaryColor.withValues(alpha: 0.2),
        highlightColor: theme.primaryColor.withValues(alpha: 0.1),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MeetingDetailScreen(meeting: meeting))),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GlassCard(
            padding: EdgeInsets.fromLTRB(16, creatorIsPremium ? 8 : 16, 16, 16),
            borderOpacity: creatorIsPremium ? 0.8 : 0.5,
            blurSigma: creatorIsPremium ? 6.0 : 3.0,
            gradient: creatorIsPremium
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFD4AF37).withValues(alpha: 0.1),
                      const Color(0xFFD4AF37).withValues(alpha: 0.05),
                    ],
                  )
                : null,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 💎 Метки PREMIUM и ПРОВЕРЕН в одной строке
                  if (creatorIsPremium || creatorIsVerified)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (creatorIsPremium)
                            Text(
                              'PREMIUM',
                              style: GoogleFonts.montserrat(
                                color: const Color(0xFFD4AF37),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3.0,
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                          if (creatorIsVerified)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified, color: Color(0xFFD4AF37), size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'VERIFIED',
                                  style: GoogleFonts.montserrat(
                                    color: const Color(0xFFD4AF37),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 3.0,
                                  ),
                                ),
                              ],
                            )
                          else
                            const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  // Первая строка: название + 🍓
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(genderIcon, color: genderColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(meeting['title'], style: GoogleFonts.montserrat(color: theme.textTheme.bodyLarge?.color, fontSize: 16, fontWeight: FontWeight.w600, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis)),
                      if (isAdult) ...[
                        const SizedBox(width: 4),
                        Text('🍓', style: TextStyle(fontSize: 18)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Вторая строка: локация + относительное время
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on, color: theme.primaryColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(meeting['location'] ?? 'Место не указано', style: GoogleFonts.montserrat(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 13, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 12),
                      Text(daysLeft, style: GoogleFonts.montserrat(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5), fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 📅 Сколько дней осталось до окончания действия предложения
  String _getDaysLeft(String? meetingDate) {
    if (meetingDate == null) return '';
    try {
      final expiry = DateTime.parse(meetingDate);
      final now = DateTime.now();
      final diff = expiry.difference(now);
      if (diff.inDays < 0) return 'истекло';
      if (diff.inDays == 0) return 'сегодня';
      if (diff.inDays == 1) return 'ещё 1 день';
      return 'ещё ${diff.inDays} дней';
    } catch (_) {
      return '';
    }
  }
}

// 🆕 Виджет для плавного появления карточек
class AnimatedMeetingCard extends StatefulWidget {
  final Widget child;
  final int index;
  const AnimatedMeetingCard({super.key, required this.child, required this.index});
  @override
  State<AnimatedMeetingCard> createState() => _AnimatedMeetingCardState();
}

class _AnimatedMeetingCardState extends State<AnimatedMeetingCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 450), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.index * 60), () { if (mounted) _controller.forward(); });
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _fadeAnimation, child: SlideTransition(position: _slideAnimation, child: widget.child));
}