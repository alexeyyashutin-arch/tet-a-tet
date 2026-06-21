import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/settings_service.dart';
import '../services/api_service.dart';
import '../widgets/app_background.dart';
import 'login_screen.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _api = ApiService();

  // 🔔 Уведомления
  bool _pushEnabled = true;
  bool _soundEnabled = true;
  bool _responsesNotify = true;
  bool _messagesNotify = true;

  // 🎨 Внешний вид
  String _language = 'ru';
  String _theme = 'basic';
  bool _isPremium = false; 

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final push = await SettingsService.isPushEnabled();
    final sound = await SettingsService.isSoundEnabled();
    final lang = await SettingsService.getLanguage();
    final theme = await SettingsService.getTheme(); 
    final isPremium = await _api.isPremium(); 

    final serverSettings = await _api.getNotificationSettings();
    final responses = serverSettings?['notify_responses'] ?? true;
    final messages = serverSettings?['notify_messages'] ?? true;

    await SettingsService.setResponsesNotifyEnabled(responses);
    await SettingsService.setMessagesNotifyEnabled(messages);

    if (mounted) {
      setState(() {
        _pushEnabled = push;
        _soundEnabled = sound;
        _responsesNotify = responses;
        _messagesNotify = messages;
        _language = lang;
        _theme = theme;
        _isPremium = isPremium;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios, color: theme.primaryColor),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'НАСТРОЙКИ',
                style: GoogleFonts.montserrat(
                  color: theme.textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // 🔔 Раздел "Уведомления"
              _buildSectionHeader('УВЕДОМЛЕНИЯ', Icons.notifications_outlined),
              const SizedBox(height: 12),
              _buildGlassCard(
                children: [
                  _buildSwitchTile(
                    icon: Icons.notifications_active,
                    title: 'Push-уведомления',
                    subtitle: 'Получать уведомления о событиях',
                    value: _pushEnabled,
                    onChanged: (value) async {
                      setState(() => _pushEnabled = value);
                      await SettingsService.setPushEnabled(value);
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.volume_up_outlined,
                    title: 'Звук',
                    subtitle: 'Звуковые сигналы уведомлений',
                    value: _soundEnabled,
                    onChanged: (value) async {
                      setState(() => _soundEnabled = value);
                      await SettingsService.setSoundEnabled(value);
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.favorite_border,
                    title: 'Новые отклики',
                    subtitle: 'Уведомлять об откликах на встречи',
                    value: _responsesNotify,
                    onChanged: (value) async {
                      setState(() => _responsesNotify = value);
                      await SettingsService.setResponsesNotifyEnabled(value);
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.chat_bubble_outline,
                    title: 'Новые сообщения',
                    subtitle: 'Уведомлять о сообщениях в чатах',
                    value: _messagesNotify,
                    onChanged: (value) async {
                      setState(() => _messagesNotify = value);
                      await SettingsService.setMessagesNotifyEnabled(value);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 🎨 Раздел "Внешний вид"
              _buildSectionHeader('ВНЕШНИЙ ВИД', Icons.palette_outlined),
              const SizedBox(height: 12),
              _buildGlassCard(
                children: [
                  _buildThemeTile(),
                  _buildDivider(),
                  _buildLanguageTile(),
                ],
              ),

              const SizedBox(height: 24),

              // 🛡️ Раздел "Безопасность"
              _buildSectionHeader('БЕЗОПАСНОСТЬ', Icons.security_outlined),
              const SizedBox(height: 12),
              _buildGlassCard(
                children: [
                  _buildActionTile(
                    icon: Icons.logout,
                    title: 'Выйти из аккаунта',
                    iconColor: Colors.orangeAccent,
                    onTap: _showLogoutDialog,
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    icon: Icons.delete_forever_outlined,
                    title: 'Удалить аккаунт',
                    iconColor: Colors.redAccent,
                    onTap: _showDeleteAccountDialog,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ℹ️ Раздел "О приложении"
              _buildSectionHeader('О ПРИЛОЖЕНИИ', Icons.info_outline),
              const SizedBox(height: 12),
              _buildGlassCard(
                children: [
                  _buildInfoTile(
                    icon: Icons.tag_outlined,
                    title: 'Версия',
                    value: '1.0.0',
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    icon: Icons.description_outlined,
                    title: 'Правила сервиса',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Скоро здесь будут правила! 📜')),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    icon: Icons.support_agent,
                    title: 'Связаться с поддержкой',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Поддержка: support@tet-a-tet.app 💌')),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // 💖 Подпись
              Center(
                child: Text(
                  'TET-A-TET • Закрытый клуб свиданий',
                  style: GoogleFonts.montserrat(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4) ?? Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🎨 Заголовок раздела
  Widget _buildSectionHeader(String title, IconData icon) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(icon, color: theme.primaryColor, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.montserrat(
              color: theme.primaryColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  // 🪟 Стеклянная карточка
  Widget _buildGlassCard({required List<Widget> children}) {
    final theme = Theme.of(context);
    final isPremium = theme.primaryColor == const Color(0xFFD4AF37);
    
    if (isPremium) {
      // 👑 В золотой теме — стеклянный эффект с blur
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.primaryColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: children,
            ),
          ),
        ),
      );
    }
    
    // 🍷 В базовой теме — тёмная карточка без blur
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  // 🔀 Переключатель
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: Icon(icon, color: theme.primaryColor, size: 24),
      title: Text(
        title,
        style: GoogleFonts.montserrat(
          color: theme.textTheme.bodyLarge?.color,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.montserrat(
          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          fontSize: 11,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: theme.primaryColor,
        activeTrackColor: theme.primaryColor.withValues(alpha: 0.5),
        inactiveThumbColor: Colors.grey,
        inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
      ),
    );
  }

  // ➡️ Кликбельная строка
  Widget _buildActionTile({
    required IconData icon,
    required String title,
    Color iconColor = const Color(0xFFD4AF37),
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 24),
      title: Text(
        title,
        style: GoogleFonts.montserrat(
          color: theme.textTheme.bodyLarge?.color,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right, 
        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4) ?? Colors.white38, 
        size: 20,
      ),
      onTap: onTap,
    );
  }

  // ℹ️ Информационная строка
  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: Icon(icon, color: theme.primaryColor, size: 24),
      title: Text(
        title,
        style: GoogleFonts.montserrat(
          color: theme.textTheme.bodyLarge?.color,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Text(
        value,
        style: GoogleFonts.montserrat(
          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          fontSize: 13,
        ),
      ),
    );
  }

  // 🌐 Выбор языка
  Widget _buildLanguageTile() {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: Icon(Icons.language, color: theme.primaryColor, size: 24),
      title: Text(
        'Язык / Language',
        style: GoogleFonts.montserrat(
          color: theme.textTheme.bodyLarge?.color,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.primaryColor.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: DropdownButton<String>(
          value: _language,
          dropdownColor: theme.scaffoldBackgroundColor,
          underline: const SizedBox(),
          icon: Icon(Icons.arrow_drop_down, color: theme.primaryColor, size: 20),
          style: GoogleFonts.montserrat(
            color: theme.primaryColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          items: const [
            DropdownMenuItem(value: 'ru', child: Text('🇷🇺 Русский')),
            DropdownMenuItem(value: 'en', child: Text('🇬🇧 English')),
          ],
          onChanged: (value) async {
            if (value != null) {
              setState(() => _language = value);
              await SettingsService.setLanguage(value);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(value == 'ru' ? 'Язык изменён на русский 🇷🇺' : 'Language changed to English 🇬🇧'),
                    backgroundColor: theme.primaryColor,
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }

  // ➖ Разделитель
  Widget _buildDivider() {
    final theme = Theme.of(context);
    
    return Divider(
      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.05) ?? Colors.white.withValues(alpha: 0.05),
      height: 1,
      indent: 72,
    );
  }

  // 🚪 Диалог выхода
  void _showLogoutDialog() {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Выйти из аккаунта?',
          style: GoogleFonts.montserrat(
            color: theme.textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Вам придётся снова вводить номер телефона для входа.',
          style: GoogleFonts.montserrat(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Отмена',
              style: GoogleFonts.montserrat(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _api.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: Text('Выйти', style: GoogleFonts.montserrat(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 🗑️ Диалог удаления аккаунта
  void _showDeleteAccountDialog() {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Удалить аккаунт?',
          style: GoogleFonts.montserrat(
            color: theme.textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Это действие нельзя отменить. Все ваши данные, фото и встречи будут удалены навсегда.',
          style: GoogleFonts.montserrat(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Отмена',
              style: GoogleFonts.montserrat(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(
                  child: CircularProgressIndicator(color: theme.primaryColor),
                ),
              );
              
              final success = await _api.deleteAccount();
              
              if (mounted) {
                Navigator.pop(context);
                
                if (success) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ошибка удаления аккаунта'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: Text('Удалить', style: GoogleFonts.montserrat(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 🎨 Выбор темы
  Widget _buildThemeTile() {
    final theme = Theme.of(context);
    // 🆕 Брендовый золотой цвет для пометки PREMIUM — всегда золотой
    const premiumGold = Color(0xFFD4AF37);
    
    return ListTile(
      leading: Icon(Icons.palette, color: theme.primaryColor, size: 24),
      title: Text(
        'Тема оформления',
        style: GoogleFonts.montserrat(
          color: theme.textTheme.bodyLarge?.color,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.primaryColor.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: DropdownButton<String>(
          value: _theme,
          dropdownColor: theme.scaffoldBackgroundColor,
          underline: const SizedBox(),
          icon: Icon(Icons.arrow_drop_down, color: theme.primaryColor, size: 20),
          style: GoogleFonts.montserrat(
            color: theme.primaryColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          items: [
            const DropdownMenuItem(value: 'basic', child: Text('🍷 Базовая')),
            DropdownMenuItem(
              value: 'premium',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('👑 Золотая'),
                  if (!_isPremium) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: premiumGold,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'PREMIUM',
                        style: GoogleFonts.montserrat(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          onChanged: _isPremium
              ? (value) async {
                  if (value != null) {
                    setState(() => _theme = value);
                    await SettingsService.setTheme(value);
                    if (mounted) {
                      final appState = context.findAncestorStateOfType<TetATetAppState>();
                      if (appState != null) {
                        appState.loadTheme();
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(value == 'basic' ? 'Тема изменена на базовую 🍷' : 'Тема изменена на золотую 👑'),
                          backgroundColor: theme.primaryColor,
                        ),
                      );
                    }
                  }
                }
              : null,
        ),
      ),
    );
  }
}