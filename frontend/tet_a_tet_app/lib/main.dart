import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/api_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/settings_service.dart';


// 🆕 ВОТ ЭТО НАДО ДОБАВИТЬ В САМЫЙ ВЕРХ (строго до main и до любых классов!)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Если нужно, чтобы в фоне тоже работал Firebase, инициализируем его и тут
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('🔔 Получено фоновое сообщение: ${message.messageId}');
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const TetATetApp());
}

class TetATetApp extends StatefulWidget {
  const TetATetApp({super.key});

  @override
  State<TetATetApp> createState() => TetATetAppState();
}

class TetATetAppState extends State<TetATetApp> {
  final _api = ApiService();
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String _theme = 'basic';  // 🆕 Тема по умолчанию

  @override
  void initState() {
    super.initState();
    _checkAuth();
    loadTheme();  // 🆕 Загружаем тему
  }

  // 🆕 Загружаем тему из настроек
  Future<void> loadTheme() async {
    final theme = await SettingsService.getTheme();
    if (mounted) {
      setState(() => _theme = theme);
    }
  }

  Future<void> _checkAuth() async {
    final token = await _api.getToken();
    
    // Если токена нет — сразу показываем экран входа
    if (token == null) {
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
      }
      return;
    }
    
    // Проверяем токен, но с таймаутом
    try {
      final profile = await _api.getProfile().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      
      if (mounted) {
        setState(() {
          _isLoggedIn = profile != null;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Если ошибка — считаем, что не авторизован
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TET-A-TET',
      debugShowCheckedModeBanner: false,
      theme: _theme == 'premium' ? AppTheme.premiumTheme : AppTheme.basicTheme,  // 🆕 Применяем тему
      localizationsDelegates: const[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      supportedLocales: const[
        Locale('ru', 'RU'),
        Locale('en', 'US'),
      ],
      home: _isLoading
          ? const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
              ),
            )
          : _isLoggedIn
              ? const MainScreen()
              : const LoginScreen(),
    );
  }
}