import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';
import '../widgets/app_background.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _api = ApiService();
  List<dynamic> _chats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() => _isLoading = true);
    final chats = await _api.getMyChats();
    if (mounted) {
      setState(() {
        _chats = chats ?? [];
        _isLoading = false;
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
              title: Text(
                'СООБЩЕНИЯ',
                style: GoogleFonts.montserrat(
                  color: theme.primaryColor, 
                  fontWeight: FontWeight.bold, 
                  letterSpacing: 2.0, 
                  fontSize: 16
                ),
              ),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: AppBackground(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
            : _chats.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Пока нет активных чатов',
                          style: GoogleFonts.montserrat(
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Откликнись на встречу или прими чью-то заявку!',
                          style: GoogleFonts.montserrat(
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      16, 
                      MediaQuery.of(context).padding.top + kToolbarHeight + 16, 
                      16, 
                      MediaQuery.of(context).padding.bottom + 16
                    ),
                    itemCount: _chats.length,
                    itemBuilder: (context, index) {
                      return _buildChatCard(_chats[index]);
                    },
                  ),
      ),
    );
  }

  Widget _buildChatCard(Map<String, dynamic> chat) {
    final theme = Theme.of(context);
    final meetingId = chat['meeting_id'];
    final meetingTitle = chat['meeting_title'] ?? 'Встреча';
    final opponentName = chat['opponent_name'] ?? 'Собеседник';
    final opponentAvatar = chat['opponent_avatar_url'];
    final lastMessage = chat['last_message'];
    final lastMessageTime = chat['last_message_time'];
    final unreadCount = chat['unread_count'] ?? 0;

    String timeStr = '';
    if (lastMessageTime != null) {
      final dateTime = DateTime.parse(lastMessageTime);
      final now = DateTime.now();
      if (now.difference(dateTime).inDays < 1) {
        timeStr = DateFormat('HH:mm').format(dateTime);
      } else {
        timeStr = DateFormat('dd.MM').format(dateTime);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.primaryColor.withValues(alpha: 0.5), width: 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  meetingId: meetingId,
                  meetingTitle: meetingTitle,
                  opponentName: opponentName,
                ),
              ),
            ).then((_) => _loadChats());
          },
          child: Row(
            children: [
              // Аватарка собеседника
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.primaryColor.withValues(alpha: 0.2),
                backgroundImage: opponentAvatar != null 
                    ? CachedNetworkImageProvider('${ApiService.baseUrl}$opponentAvatar') 
                    : null,
                child: opponentAvatar == null 
                    ? Icon(Icons.person, color: theme.primaryColor, size: 28) 
                    : null,
              ),
              const SizedBox(width: 16),
              
              // Информация о чате
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            opponentName,
                            style: GoogleFonts.montserrat(
                              color: theme.textTheme.bodyLarge?.color,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (timeStr.isNotEmpty)
                          Text(
                            timeStr,
                            style: GoogleFonts.montserrat(
                              color: unreadCount > 0 ? theme.primaryColor : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'По поводу: $meetingTitle',
                      style: GoogleFonts.montserrat(
                        color: theme.primaryColor,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessage ?? 'Нет сообщений',
                            style: GoogleFonts.montserrat(
                              color: unreadCount > 0 
                                  ? theme.textTheme.bodyLarge?.color 
                                  : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unreadCount > 9 ? '9+' : unreadCount.toString(),
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}