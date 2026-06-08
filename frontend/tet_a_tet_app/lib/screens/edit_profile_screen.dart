import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../widgets/background_pattern.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> currentProfile;

  const EditProfileScreen({super.key, required this.currentProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  final bool _isUploadingAvatar = false;

  late TextEditingController _usernameController;
  late TextEditingController _dobController; // Теперь это дата рождения
  late TextEditingController _bioController;
  String? _selectedGender;
  DateTime? _selectedDate; // Храним выбранную дату
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.currentProfile['username'] ?? '');
    _bioController = TextEditingController(text: widget.currentProfile['bio'] ?? '');
    _selectedGender = widget.currentProfile['gender'];
    
    // Если дата рождения уже есть, парсим её
    if (widget.currentProfile['birth_date'] != null) {
      _selectedDate = DateTime.parse(widget.currentProfile['birth_date']);
      _dobController = TextEditingController(text: _formatDate(_selectedDate!));
    } else {
      _dobController = TextEditingController();
    }
  }

  // Красивый форматтер даты: ДД.ММ.ГГГГ
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  // Показываем элегантный тёмный календарь
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1925),
      lastDate: DateTime.now(),
      builder: (context, child) {
        // Делаем календарь тёмным и золотым, в стиле нашего приложения!
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
      setState(() {
        _selectedDate = picked;
        _dobController.text = _formatDate(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        // backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text('Редактировать', style: TextStyle(color: Color(0xFFD4AF37))),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFFD4AF37), strokeWidth: 2))
                : const Text('СОХРАНИТЬ', style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ],
      ),
      body: BackgroundPattern(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(_usernameController, 'Имя или никнейм', Icons.person),
                const SizedBox(height: 16),
                
                // Поле даты рождения
                const Text('Дата рождения', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _dobController,
                  readOnly: true, // Запрещаем ввод с клавиатуры, только календарь!
                  onTap: () => _selectDate(context),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Выбери дату',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.cake, color: Color(0xFFD4AF37)),
                    suffixIcon: const Icon(Icons.calendar_today, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
            
                // Пол
                const Text('Пол', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedGender,
                  dropdownColor: const Color(0xFF1E1E1E),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Мужской', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'female', child: Text('Женский', style: TextStyle(color: Colors.white))),
                  ],
                  onChanged: (value) => setState(() => _selectedGender = value),
                ),
                const SizedBox(height: 24),
            
                // Био
                const Text('О себе', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bioController,
                  maxLines: 5,
                  maxLength: 500,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Расскажи, что ты ищешь...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(hint, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            prefixIcon: Icon(icon, color: const Color(0xFFD4AF37)),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final data = {
      'username': _usernameController.text.trim().isNotEmpty ? _usernameController.text.trim() : null,
      'birth_date': _selectedDate != null ? _formatDate(_selectedDate!).split('.').reversed.join('-') : null, // Превращаем ДД.ММ.ГГГГ в ГГГГ-ММ-ДД для бэкенда
      'gender': _selectedGender,
      'bio': _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
    };

    final success = await _api.updateProfile(data);
    setState(() => _isSaving = false);

    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить.'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _dobController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}