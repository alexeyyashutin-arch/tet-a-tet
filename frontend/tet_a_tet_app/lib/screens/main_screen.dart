import 'package:flutter/material.dart';
import 'meetings_feed_screen.dart';
import 'my_meetings_screen.dart';
import 'profile_screen.dart';
import 'albums_screen.dart';
import 'chat_list_screen.dart';
import '../services/api_service.dart';
import 'dart:ui';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _totalUnread = 0; // 🆕 Общий счетчик непрочитанных сообщений
  
  final List<Widget> _screens = [
    const MeetingsFeedScreen(),
    const MyMeetingsScreen(),
    const ProfileScreen(),
    const AlbumsScreen(isMyProfile: true),
    const ChatListScreen(), // 🆕 Добавляем экран чатов!
  ];

  @override
  void initState() {
    super.initState();
    _updateUnreadCount(); // 🆕 Считаем непрочитанные при запуске
  }

  // 🆕 Метод для обновления счетчика непрочитанных
  Future<void> _updateUnreadCount() async {
    final chats = await ApiService().getMyChats();
    if (mounted) {
      setState(() {
        _totalUnread = chats?.fold<int>(0, (sum, chat) => sum + ((chat['unread_count'] ?? 0) as int)) ?? 0;
      });
    }
  }

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
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() => _currentIndex = index);
                if (index == 4) { // 🆕 Если перешли на вкладку чатов
                  _updateUnreadCount(); // Обновляем счетчик
                }
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: const Color(0xFFD4AF37),
              unselectedItemColor: Colors.grey,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              items: [ // 🆕 Убрали const, потому что теперь есть переменная _totalUnread
                const BottomNavigationBarItem(
                  icon: Icon(Icons.event, size: 28),
                  label: 'Встречи',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.list_alt, size: 28),
                  label: 'Моё',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person, size: 28),
                  label: 'Профиль',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.photo_library, size: 28),
                  label: 'Альбом',
                ),
                BottomNavigationBarItem( // 🆕 Иконка чата с бейджиком
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 26),
                      if (_totalUnread > 0)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Text(
                              _totalUnread > 9 ? '9+' : _totalUnread.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: '', // 🆕 Без подписи!
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}