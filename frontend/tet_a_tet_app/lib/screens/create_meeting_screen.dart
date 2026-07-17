import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/background_pattern.dart';

class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isCreating = false;
  bool _isPremium = false;
  bool _isAdult = false;
  int _durationDays = 7;

  // 🎯 Пожелания к партнёру
  String? _partnerGender;          // male / female / null (не важно)
  int _partnerMinAge = 18;
  int _partnerMaxAge = 80;
  String _partnerMaritalStatus = 'Не важно';   // Не важно / Не в браке / В браке
  String _partnerHasChildren = 'Не важно';      // Не важно / Есть / Нет

  String? _userGender;
  int? _userAge;

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
      final age = profile['age'] as int?;

      setState(() {
        _isPremium = isPremium;
        _userGender = gender;
        _userAge = age;

        // Дефолтный пол — противоположный
        if (_partnerGender == null) {
          if (gender == 'male') {
            _partnerGender = 'female';
          } else if (gender == 'female') {
            _partnerGender = 'male';
          }
        }

        // Дефолтный возрастной диапазон
        if (age != null) {
          if (gender == 'male') {
            _partnerMinAge = (age - 10).clamp(18, 80);
            _partnerMaxAge = (age + 5).clamp(18, 80);
          } else {
            _partnerMinAge = (age - 5).clamp(18, 80);
            _partnerMaxAge = (age + 10).clamp(18, 80);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createMeeting() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    final data = {
      'title': _titleController.text.trim(),
      'location': _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
      'description': _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
      'finance': 'none',
      'is_adult': _isAdult,
      'meeting_date': DateFormat('yyyy-MM-dd').format(
        DateTime.now().add(Duration(days: _durationDays)),
      ),
      // 🎯 Пожелания к партнёру
      'partner_gender': _partnerGender,
      'partner_min_age': _partnerMinAge,
      'partner_max_age': _partnerMaxAge,
      'partner_marital_status': _partnerMaritalStatus == 'Не важно' ? null : _partnerMaritalStatus,
      'partner_has_children': _partnerHasChildren == 'Не важно' ? null : _partnerHasChildren,
    };

    final success = await _api.createMeeting(data);
    
    if (mounted) {
      setState(() => _isCreating = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Встреча успешно создана! '), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось создать встречу'), backgroundColor: Colors.redAccent),
        );
      }
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
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'НОВАЯ ВСТРЕЧА',
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
            16,
            MediaQuery.of(context).padding.top + kToolbarHeight + 16,
            16,
            MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 16,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🍓 Выбор типа встречи (только для премиум)
                if (_isPremium) ...[
                  _buildMeetingTypeSwitcher(),
                  const SizedBox(height: 24),
                ],

                _buildTextField(_titleController, 'Название встречи', Icons.event, maxLines: 1, minLength: 5),
                const SizedBox(height: 16),
                
                _buildTextField(_locationController, 'Место встречи', Icons.location_on, maxLines: 1),
                const SizedBox(height: 16),
                
                _buildTextField(_descriptionController, 'Описание', Icons.description, maxLines: 4),
                const SizedBox(height: 24),

                // 📅 Срок действия предложения
                _buildDurationSelector(),
                const SizedBox(height: 24),

                // 🎯 ПОЖЕЛАНИЯ К ПАРТНЁРУ
                Text('ПОЖЕЛАНИЯ К ПАРТНЁРУ', style: GoogleFonts.montserrat(color: const Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 16),

                // 👤 Пол
                _buildSectionLabel('Пол'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildGenderButton('male', 'Мужской', Icons.male),
                    const SizedBox(width: 12),
                    _buildGenderButton('female', 'Женский', Icons.female),
                    const SizedBox(width: 12),
                    _buildGenderButton(null, 'Не важно', Icons.transgender),
                  ],
                ),
                const SizedBox(height: 20),

                // 🎂 Возраст
                _buildSectionLabel('Возраст'),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    '$_partnerMinAge — $_partnerMaxAge лет',
                    style: GoogleFonts.montserrat(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFD4AF37),
                    inactiveTrackColor: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                    thumbColor: const Color(0xFFD4AF37),
                    overlayColor: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                    rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
                    rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
                  ),
                  child: RangeSlider(
                    values: RangeValues(_partnerMinAge.toDouble(), _partnerMaxAge.toDouble()),
                    min: 18, max: 80, divisions: 62,
                    labels: RangeLabels(_partnerMinAge.toString(), _partnerMaxAge.toString()),
                    onChanged: (values) => setState(() {
                      _partnerMinAge = values.start.toInt();
                      _partnerMaxAge = values.end.toInt();
                    }),
                  ),
                ),
                const SizedBox(height: 16),

                // 💍 Семейное положение
                _buildSectionLabel('Семейное положение'),
                const SizedBox(height: 8),
                _buildDropdown(['Не важно', 'Не в браке', 'В браке'], _partnerMaritalStatus, (val) {
                  setState(() => _partnerMaritalStatus = val!);
                }),
                const SizedBox(height: 16),

                // 👶 Дети
                _buildSectionLabel('Дети'),
                const SizedBox(height: 8),
                _buildDropdown(['Не важно', 'Есть', 'Нет'], _partnerHasChildren, (val) {
                  setState(() => _partnerHasChildren = val!);
                }),
                const SizedBox(height: 32),
                
                // Кнопка создания
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                    ),
                    onPressed: _isCreating ? null : _createMeeting,
                    child: _isCreating
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                          )
                        : Text(
                            'СОЗДАТЬ ВСТРЕЧУ',
                            style: GoogleFonts.montserrat(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(text, style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12));
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {int maxLines = 1, int minLength = 1, bool isRequired = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(hint, style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.montserrat(color: Colors.white),
          validator: (value) {
            if (isRequired && (value == null || value.trim().isEmpty)) {
              return 'Обязательное поле';
            }
            if (value != null && value.trim().isNotEmpty && value.trim().length < minLength) {
              return 'Минимум $minLength символов';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.montserrat(color: Colors.grey),
            prefixIcon: Icon(icon, color: const Color(0xFFD4AF37)),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), 
              borderSide: BorderSide(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), 
              borderSide: BorderSide(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), 
              borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
            ),
            errorStyle: GoogleFonts.montserrat(color: Colors.redAccent, fontSize: 12),
          ),
        ),
      ],
    );
  }

  // 👤 Кнопка выбора пола партнёра
  Widget _buildGenderButton(String? gender, String label, IconData icon) {
    final isSelected = _partnerGender == gender;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _partnerGender = gender),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFD4AF37).withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFFD4AF37).withValues(alpha: 0.3),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? const Color(0xFFD4AF37) : Colors.grey, size: 22),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.montserrat(
                color: isSelected ? const Color(0xFFD4AF37) : Colors.grey,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              )),
            ],
          ),
        ),
      ),
    );
  }

  // 🔽 Выпадающий список
  Widget _buildDropdown(List<String> items, String currentValue, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
      ),
      child: DropdownButton<String>(
        value: currentValue,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF1E1E1E),
        style: GoogleFonts.montserrat(color: Colors.white, fontSize: 14),
        items: items.map((item) => DropdownMenuItem(
          value: item,
          child: Text(item, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 14)),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }

  // 📅 Выбор срока действия: Сегодня / Неделю / Месяц
  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Предложение действует', style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildDurationButton('Сегодня', 0, Icons.today),
            const SizedBox(width: 12),
            _buildDurationButton('Неделю', 7, Icons.date_range),
            const SizedBox(width: 12),
            _buildDurationButton('Месяц', 30, Icons.event),
          ],
        ),
      ],
    );
  }

  Widget _buildDurationButton(String label, int days, IconData icon) {
    final isSelected = _durationDays == days;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _durationDays = days),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFD4AF37).withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFFD4AF37).withValues(alpha: 0.3),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? const Color(0xFFD4AF37) : Colors.grey, size: 20),
              const SizedBox(height: 6),
              Text(label, style: GoogleFonts.montserrat(
                color: isSelected ? const Color(0xFFD4AF37) : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              )),
            ],
          ),
        ),
      ),
    );
  }

  // 🍓 Стильный переключатель: Дружеская встреча ↔ Клубничка
  Widget _buildMeetingTypeSwitcher() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ТИП ВСТРЕЧИ', style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isAdult = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: !_isAdult ? const Color(0xFFD4AF37).withValues(alpha: 0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people, color: !_isAdult ? const Color(0xFFD4AF37) : Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Text('Дружеская', style: GoogleFonts.montserrat(
                          color: !_isAdult ? const Color(0xFFD4AF37) : Colors.grey,
                          fontSize: 12,
                          fontWeight: !_isAdult ? FontWeight.bold : FontWeight.normal,
                        )),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isAdult = true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _isAdult ? const Color(0xFFD4AF37).withValues(alpha: 0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🍓', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text('С продолжением', style: GoogleFonts.montserrat(
                          color: _isAdult ? const Color(0xFFD4AF37) : Colors.grey,
                          fontSize: 12,
                          fontWeight: _isAdult ? FontWeight.bold : FontWeight.normal,
                        )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}