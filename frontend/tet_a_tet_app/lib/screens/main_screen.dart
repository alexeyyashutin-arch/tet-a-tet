import 'package:flutter/material.dart';
import 'meetings_feed_screen.dart';
import 'my_meetings_screen.dart';
import 'profile_screen.dart';
import 'albums_screen.dart';
import 'dart:ui';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const MeetingsFeedScreen(),
    const MyMeetingsScreen(),
    const ProfileScreen(),
    const AlbumsScreen(isMyProfile: true), // 🆕 Без userId!
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // 🆕 Blur-эффект
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2), // 🆕 Более прозрачный
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: const Color(0xFFD4AF37),
              unselectedItemColor: Colors.grey,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.event, size: 28),
                  label: 'Встречи',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.list_alt, size: 28),
                  label: 'Моё',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person, size: 28),
                  label: 'Профиль',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.photo_library, size: 28),
                  label: 'Альбом',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}