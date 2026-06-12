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
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _wishesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD4AF37),
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD4AF37),
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _createMeeting() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выбери дату и время'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isCreating = true);

    // Форматируем дату и время для бэкенда
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    // final timeStr = DateFormat('HH:mm').format(DateTime(
    //   2023, 1, 1, _selectedTime!.hour, _selectedTime!.minute,
    // ));

    final data = {
      'title': _titleController.text.trim(),
      'meeting_date': dateStr,
      'meeting_time': _selectedTime != null 
          ? DateFormat('HH:mm').format(DateTime(2023, 1, 1, _selectedTime!.hour, _selectedTime!.minute)) 
          : null,
      'location': _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
      'description': _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
      'partner_wishes': _wishesController.text.trim().isNotEmpty ? _wishesController.text.trim() : null,
      'finance': 'none', // 🆕 Скрываем от пользователя, отправляем дефолтное значение на бэкенд
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
              backgroundColor: Colors.black.withOpacity(0.3),
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
                _buildTextField(_titleController, 'Название встречи', Icons.event, maxLines: 1, minLength: 5),
                const SizedBox(height: 16),
                
                // Дата и время в одной строке
                Row(
                  children: [
                    Expanded(
                      child: _buildDateButton(),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTimeButton(),
                    ),
                  ],
                ),
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
                      shadowColor: const Color(0xFFD4AF37).withOpacity(0.4),
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
            fillColor: Colors.black.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), 
              borderSide: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), 
              borderSide: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3)),
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

  Widget _buildDateButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Дата', style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFFD4AF37), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedDate != null ? DateFormat('dd.MM.yyyy').format(_selectedDate!) : 'Выбрать дату',
                    style: GoogleFonts.montserrat(
                      color: _selectedDate != null ? Colors.white : Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Время', style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectTime,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Color(0xFFD4AF37), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedTime != null ? _selectedTime!.format(context) : 'Выбрать время',
                    style: GoogleFonts.montserrat(
                      color: _selectedTime != null ? Colors.white : Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}