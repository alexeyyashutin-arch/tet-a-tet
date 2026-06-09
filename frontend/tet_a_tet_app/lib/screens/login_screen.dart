import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tet_a_tet_app/screens/main_screen.dart';
import '../services/api_service.dart';
import '../widgets/background_pattern.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController(text: '+7 ');
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();
  final _api = ApiService();
  
  bool _isCodeSent = false;
  String _statusMessage = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // Няня для телефона
    _phoneController.addListener(() {
      if (!_phoneController.text.startsWith('+7 ')) {
        _phoneController.text = '+7 ';
        _phoneController.selection = TextSelection.fromPosition(
          TextPosition(offset: _phoneController.text.length),
        );
      }
    });

    // Магия авто-отправки кода!
    _codeController.addListener(() {
      if (_codeController.text.length == 4) {
        _codeFocusNode.unfocus();
        _handleButtonPress();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BackgroundPattern(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                
                // 👑 Логотип
                Text(
                  'TET-A-TET',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    color: const Color(0xFFD4AF37),
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4.0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Закрытый клуб свиданий',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    color: Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 2.0,
                  ),
                ),
                
                const Spacer(flex: 3),
            
                // 📱 Стеклянное поле ввода телефона
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFD4AF37).withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        // inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: '+7 999 123 45 67',
                          hintStyle: GoogleFonts.montserrat(color: Colors.white38, fontSize: 16),
                          prefixIcon: const Icon(Icons.phone_android, color: Color(0xFFD4AF37)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
            
                // 🔢 Стеклянное поле ввода СМС (появляется после отправки кода)
                if (_isCodeSent)
                  ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFD4AF37).withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _codeController,
                          focusNode: _codeFocusNode,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          maxLength: 4,
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: '----',
                            hintStyle: GoogleFonts.montserrat(color: Colors.white38, fontSize: 24),
                            border: InputBorder.none,
                            counterText: '',
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ),
                  ),
                
                if (_isCodeSent) const SizedBox(height: 16),
            
                // ⚠️ Текст ошибки/успеха
                if (_statusMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        color: _statusMessage.contains('Ошибка') || _statusMessage.contains('Неверный') || _statusMessage.contains('Подождите') 
                            ? Colors.redAccent 
                            : Colors.greenAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                
                // ✨ Золотая кнопка (только на первом этапе)
                if (!_isCodeSent)
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
                      onPressed: _isLoading ? null : _handleButtonPress,
                      child: _isLoading 
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                            )
                          : Text(
                              'ПОЛУЧИТЬ КОД',
                              style: GoogleFonts.montserrat(
                                color: Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ),
                
                const Spacer(flex: 2),
                
                // Мелкий текст внизу с подложкой
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Нажимая кнопку, вы соглашаетесь с правилами сервиса',
                    style: GoogleFonts.montserrat(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
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

  Future<void> _handleButtonPress() async {
    setState(() { _isLoading = true; _statusMessage = ''; });

    if (!_isCodeSent) {
      final cleanPhone = _phoneController.text.replaceAll(' ', '');
      final result = await _api.sendCode(cleanPhone);
      setState(() {
        _isCodeSent = true;
        _statusMessage = result ?? '';
        _isLoading = false;
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _codeFocusNode.requestFocus();
      });
    } else {
      final cleanPhone = _phoneController.text.replaceAll(' ', '');
      final token = await _api.verifyCode(cleanPhone, _codeController.text.trim());
      setState(() { _isLoading = false; });
      
      if (token != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else {
        setState(() {
          _statusMessage = 'Неверный код или истекло время';
          _codeController.clear();
          _codeFocusNode.requestFocus();
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }
}