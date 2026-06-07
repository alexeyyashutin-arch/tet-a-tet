import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const TetATetApp());
}

class TetATetApp extends StatefulWidget {
  const TetATetApp({super.key});

  @override
  State<TetATetApp> createState() => _TetATetAppState();
}

class _TetATetAppState extends State<TetATetApp> {
  final _api = ApiService();
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await _api.getToken();
    if (mounted) {
      setState(() {
        _isLoggedIn = token != null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TET-A-TET',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: _isLoading
          ? const Scaffold(
              backgroundColor: Color(0xFF121212),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
              ),
            )
          : _isLoggedIn
              ? const ProfileScreen()
              : const LoginScreen(),
    );
  }
}