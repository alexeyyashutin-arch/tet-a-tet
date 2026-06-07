import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'profile_screen.dart';
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

  final Color _bgColor = const Color(0xFF121212); 
  final Color _accentColor = const Color(0xFFD4AF37); 

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
      // Как только ввели 4 цифры — убираем фокус (закрываем клавиатуру) и отправляем запрос
      if (_codeController.text.length == 4) {
        _codeFocusNode.unfocus();
        _handleButtonPress();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: BackgroundPattern(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'TET-A-TET',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Приватные встречи для своих',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 60),
            
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: InputDecoration(
                    hintText: '+7 999 123 45 67',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.phone_android, color: Color(0xFFD4AF37)),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
            
                if (_isCodeSent)
                  TextField(
                    controller: _codeController,
                    focusNode: _codeFocusNode,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '----',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      counterText: '', 
                    ),
                  ),
                if (_isCodeSent) const SizedBox(height: 16),
            
                if (_statusMessage.isNotEmpty)
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _statusMessage.contains('Ошибка') || _statusMessage.contains('Неверный') || _statusMessage.contains('Подождите') 
                          ? Colors.redAccent 
                          : Colors.greenAccent
                    ),
                  ),
                const SizedBox(height: 32),
            
                // Кнопка нужна только на первом этапе. На втором пользователь просто вводит код!
                if (!_isCodeSent)
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleButtonPress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Text('Получить код', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
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
        // УРА! Токен получен. Плавно переходим на главный экран и удаляем экран входа из истории
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
      } else {
        setState(() {
          _statusMessage = 'Неверный код или истекло время';
          _codeController.clear(); // Очищаем поле, чтобы можно было попробовать снова
          _codeFocusNode.requestFocus(); // Возвращаем фокус
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