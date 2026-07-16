import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // Для форматирования даты и времени
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
  final _wishesController = TextEditingController();
  
  bool _isCreating = false;
  bool _isPremium = false;  // 🍓 Премиум-статус
  bool _isAdult = false;    // 🍓 Тип встречи: обычная или Клубничка

  @override
  void initState() {
    super.initState();
    _loadPremiumStatus();
  }

  Future<void> _loadPremiumStatus() async {
    final profile = await _api.getProfile();
    if (mounted && profile != null) {
      setState(() {
        _isPremium = profile['is_premium'] == true;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _wishesController.dispose();
    super.dispose();
  }

  Future<void> _createMeeting() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    final data = {
      'title': _titleController.text.trim(),
      'location': _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
      'description': _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
      'partner_wishes': _wishesController.text.trim().isNotEmpty ? _wishesController.text.trim() : null,
      'finance': 'none',
      'is_adult': _isAdult,  // 🍓 Клубничка
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
                // 🍓 Выбор типа встречи (только для премиум) — в самом начале!
                if (_isPremium) ...[
                  _buildMeetingTypeSwitcher(),
                  const SizedBox(height: 24),
                ],

                _buildTextField(_titleController, 'Название встречи', Icons.event, maxLines: 1, minLength: 5),
                const SizedBox(height: 16),
                
                _buildTextField(_locationController, 'Место встречи', Icons.location_on, maxLines: 1),
                const SizedBox(height: 16),
                
                _buildTextField(_descriptionController, 'Описание', Icons.description, maxLines: 4),
                const SizedBox(height: 16),
                
                _buildTextField(_wishesController, 'Пожелания к партнеру', Icons.favorite, maxLines: 3, isRequired: false),
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
            // 🆕 Проверяем обязательность только если isRequired == true
            if (isRequired && (value == null || value.trim().isEmpty)) {
              return 'Обязательное поле';
            }
            // Проверяем длину только если поле не пустое
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
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
            ),
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
                      color: !_isAdult
                          ? const Color(0xFFD4AF37).withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people,
                          color: !_isAdult ? const Color(0xFFD4AF37) : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Дружеская',
                          style: GoogleFonts.montserrat(
                            color: !_isAdult ? const Color(0xFFD4AF37) : Colors.grey,
                            fontSize: 12,
                            fontWeight: !_isAdult ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
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
                      color: _isAdult
                          ? const Color(0xFFD4AF37).withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🍓', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(
                          'С продолжением',
                          style: GoogleFonts.montserrat(
                            color: _isAdult ? const Color(0xFFD4AF37) : Colors.grey,
                            fontSize: 12,
                            fontWeight: _isAdult ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
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
