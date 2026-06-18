import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../widgets/background_pattern.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _api = ApiService();
  final ImagePicker _picker = ImagePicker();
  
  File? _selectedImage;
  bool _isLoading = false;
  bool _isSubmitting = false;
  
  // Статус верификации
  bool _isVerified = false;
  String? _status; // null, "pending", "approved", "rejected"
  String? _adminComment;
  String? _createdAt;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    
    final statusData = await _api.getVerificationStatus();
    
    if (mounted) {
      setState(() {
        _isVerified = statusData?['is_verified'] ?? false;
        _status = statusData?['status'];
        _adminComment = statusData?['admin_comment'];
        _createdAt = statusData?['created_at'];
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  Future<void> _submitRequest() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала сделайте селфи! 📸'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    
    final result = await _api.submitVerificationRequest(_selectedImage!);
    
    if (mounted) {
      setState(() => _isSubmitting = false);
      
      if (result != null && result['error'] == null) {
        // Успех!
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заявка отправлена! Ожидайте проверки ✨'),
            backgroundColor: Color(0xFFD4AF37),
          ),
        );
        _loadStatus();
        setState(() => _selectedImage = null);
      } else {
        // Ошибка
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result?['error'] ?? 'Ошибка отправки'),
            backgroundColor: Colors.redAccent,
          ),
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
                icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFD4AF37)),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'ВЕРИФИКАЦИЯ',
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
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Уже верифицирован
    if (_isVerified) {
      return _buildVerifiedContent();
    }
    
    // Заявка на рассмотрении
    if (_status == 'pending') {
      return _buildPendingContent();
    }
    
    // Заявка отклонена
    if (_status == 'rejected') {
      return _buildRejectedContent();
    }
    
    // Нет заявки — показываем форму
    return _buildFormContent();
  }

  // ✅ Уже верифицирован
  Widget _buildVerifiedContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFFFFD700)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.verified, color: Colors.black, size: 80),
            ),
            const SizedBox(height: 32),
            Text(
              'ВЫ ВЕРИФИЦИРОВАНЫ!',
              style: GoogleFonts.montserrat(
                color: const Color(0xFFD4AF37),
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Теперь рядом с вашим именем будет красоваться золотая галочка доверия. Другие пользователи будут видеть, что вы — реальный человек!',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ⏳ Заявка на рассмотрении
  Widget _buildPendingContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_empty, color: Color(0xFFD4AF37), size: 80),
            const SizedBox(height: 32),
            Text(
              'ЗАЯВКА НА РАССМОТРЕНИИ',
              style: GoogleFonts.montserrat(
                color: const Color(0xFFD4AF37),
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ваша заявка отправлена и скоро будет проверена нашей командой. Обычно это занимает от нескольких минут до 24 часов.',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (_createdAt != null) ...[
              const SizedBox(height: 24),
              Text(
                'Подана: ${_formatDate(_createdAt!)}',
                style: GoogleFonts.montserrat(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ❌ Заявка отклонена
  Widget _buildRejectedContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 80),
          const SizedBox(height: 24),
          Text(
            'ЗАЯВКА ОТКЛОНЕНА',
            style: GoogleFonts.montserrat(
              color: Colors.redAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          if (_adminComment != null && _adminComment!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Комментарий:',
                    style: GoogleFonts.montserrat(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _adminComment!,
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          Text(
            'Не переживайте! Вы можете подать новую заявку. Убедитесь, что на фото хорошо видно ваше лицо.',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          _buildImagePicker(),
          const SizedBox(height: 24),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  // 📝 Форма подачи заявки
  Widget _buildFormContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.verified_outlined, color: Color(0xFFD4AF37), size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ПОЛУЧИТЬ ГАЛОЧКУ',
                      style: GoogleFonts.montserrat(
                        color: const Color(0xFFD4AF37),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Золотой знак доверия',
                      style: GoogleFonts.montserrat(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Описание
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Зачем нужна верификация?',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildBenefit(Icons.star, 'Золотая галочка рядом с именем'),
                _buildBenefit(Icons.shield, 'Больше доверия от других пользователей'),
                _buildBenefit(Icons.trending_up, 'Приоритет в ленте встреч'),
                _buildBenefit(Icons.favorite, 'Больше откликов на ваши встречи'),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Инструкция
          Text(
            'КАК ПРОЙТИ ВЕРИФИКАЦИЮ',
            style: GoogleFonts.montserrat(
              color: const Color(0xFFD4AF37),
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildStep(1, 'Сделайте селфи при хорошем освещении'),
          _buildStep(2, 'Убедитесь, что лицо хорошо видно'),
          _buildStep(3, 'Отправьте фото на проверку'),
          
          const SizedBox(height: 24),
          
          // Загрузка фото
          _buildImagePicker(),
          
          const SizedBox(height: 24),
          
          // Кнопка отправки
          _buildSubmitButton(),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildBenefit(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFD4AF37), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.montserrat(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
              border: Border.all(color: const Color(0xFFD4AF37)),
            ),
            child: Center(
              child: Text(
                '$number',
                style: GoogleFonts.montserrat(
                  color: const Color(0xFFD4AF37),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: GoogleFonts.montserrat(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedImage != null 
                ? const Color(0xFFD4AF37) 
                : const Color(0xFFD4AF37).withValues(alpha: 0.3),
            width: _selectedImage != null ? 2 : 1,
          ),
        ),
        child: _selectedImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_selectedImage!, fit: BoxFit.cover),
                    Container(
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.all(8),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => setState(() => _selectedImage = null),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    Container(
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Text(
                        'Нажмите, чтобы изменить фото',
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo, color: Color(0xFFD4AF37), size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Нажмите, чтобы сделать селфи',
                    style: GoogleFonts.montserrat(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD4AF37),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          shadowColor: const Color(0xFFD4AF37).withValues(alpha: 0.4),
        ),
        onPressed: _isSubmitting || _selectedImage == null ? null : _submitRequest,
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
              )
            : Text(
                'ОТПРАВИТЬ НА ПРОВЕРКУ',
                style: GoogleFonts.montserrat(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inMinutes < 60) return '${diff.inMinutes} мин. назад';
      if (diff.inHours < 24) return '${diff.inHours} ч. назад';
      return '${diff.inDays} дн. назад';
    } catch (e) {
      return isoDate;
    }
  }
}