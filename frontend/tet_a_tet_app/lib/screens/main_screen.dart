import 'package:flutter/material.dart';
import 'meetings_feed_screen.dart';
import 'my_meetings_screen.dart';
import 'profile_screen.dart';
import 'albums_screen.dart';
import 'chat_list_screen.dart';
import '../services/api_service.dart';
import 'dart:ui';
import '../services/push_notification_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _totalUnreadChats = 0; // 🆕 Счётчик непрочитанных сообщений в чатах
  int _totalUnreadResponses = 0; // 🆕 Счётчик непрочитанных откликов на встречи

  // 🆕 Создаём ключ для ProfileScreen, чтобы можно было вызывать его методы
  final GlobalKey<ProfileScreenState> _profileScreenKey = GlobalKey<ProfileScreenState>();
  
  final List<Widget> _screens = [];
  
  @override
  void initState() {
    super.initState();
    _screens.addAll([
      const MeetingsFeedScreen(),
      const MyMeetingsScreen(),
      ProfileScreen(key: _profileScreenKey),
      const AlbumsScreen(isMyProfile: true),
      const ChatListScreen(),
    ]);
    _updateUnreadChatsCount();
    _updateUnreadResponsesCount();
    
    // 🆕 Регистрируем обработчик навигации по уведомлениям
    PushNotificationService.onNavigation(_handlePushNavigation);
    
    // 🆕 Проверяем, не было ли открытия через уведомление
    final pendingNav = PushNotificationService.getPendingNavigation();
    if (pendingNav != null) {
      _handlePushNavigation(pendingNav);
      PushNotificationService.clearPendingNavigation();
    }
  }

  // 🆕 Обработчик навигации по push-уведомлениям
  void _handlePushNavigation(Map<String, dynamic> data) {
    final type = data['type'];
    final meetingId = data['meeting_id'];
    
    print('🧭 Навигация по уведомлению: type=$type, meeting_id=$meetingId');
    
    if (type == 'new_message' && meetingId != null) {
      // 🆕 Просто переключаемся на вкладку чатов — нужный чат будет сверху!
      setState(() {
        _currentIndex = 4; // Вкладка "Чаты"
      });
      _updateUnreadChatsCount();
    } else if (type == 'new_response' && meetingId != null) {
      // Переходим на вкладку "Моё" со списком откликов
      setState(() {
        _currentIndex = 1; // Вкладка "Моё"
      });
      _updateUnreadResponsesCount();
    }
  }

  // 🆕 Метод для обновления счётчика непрочитанных чатов
  Future<void> _updateUnreadChatsCount() async {
    final chats = await ApiService().getMyChats();
    if (mounted) {
      setState(() {
        _totalUnreadChats = chats?.fold<int>(0, (sum, chat) => sum + ((chat['unread_count'] ?? 0) as int)) ?? 0;
      });
    }
  }

  // 🆕 Метод для обновления счётчика непрочитанных откликов
  Future<void> _updateUnreadResponsesCount() async {
    final response = await ApiService().getMyMeetings();
    if (mounted) {
      setState(() {
        _totalUnreadResponses = response?['total_unread_responses'] ?? 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPremiumTheme = theme.brightness == Brightness.dark && theme.primaryColor == const Color(0xFFD4AF37);
    
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: isPremiumTheme
          ? ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                  ),
                  child: _buildBottomNavBar(context),
                ),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: _buildBottomNavBar(context),
            ),
    );
  }

  // 🆕 Выносим BottomNavigationBar в отдельный метод
  Widget _buildBottomNavBar(BuildContext context) {
    final theme = Theme.of(context);
    
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() => _currentIndex = index);
        if (index == 4) {
          _updateUnreadChatsCount();
        } else if (index == 1) {
          _updateUnreadResponsesCount();
        } else if (index == 2) {
          _profileScreenKey.currentState?.loadProfile();
        }
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.transparent,
      elevation: 0,
      selectedItemColor: theme.primaryColor,
      unselectedItemColor: theme.iconTheme.color?.withValues(alpha: 0.5) ?? Colors.grey,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.event, size: 28, color: _currentIndex == 0 ? theme.primaryColor : null),
          label: 'Встречи',
        ),
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.list_alt, size: 28, color: _currentIndex == 1 ? theme.primaryColor : null),
              if (_totalUnreadResponses > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      _totalUnreadResponses > 9 ? '9+' : _totalUnreadResponses.toString(),
                      style: TextStyle(
                        color: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person, size: 28, color: _currentIndex == 2 ? theme.primaryColor : null),
          label: 'Профиль',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.photo_library, size: 28, color: _currentIndex == 3 ? theme.primaryColor : null),
          label: 'Альбом',
        ),
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.chat_bubble_outline, size: 26, color: _currentIndex == 4 ? theme.primaryColor : null),
              if (_totalUnreadChats > 0)
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
                      _totalUnreadChats > 9 ? '9+' : _totalUnreadChats.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          label: '',
        ),
      ],
    );
  }
}