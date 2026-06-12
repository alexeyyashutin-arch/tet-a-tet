import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/background_pattern.dart';

class ChatScreen extends StatefulWidget {
  final String meetingId;
  final String meetingTitle;
  final String opponentName;

  const ChatScreen({
    super.key,
    required this.meetingId,
    required this.meetingTitle,
    required this.opponentName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _api = ApiService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  
  List<dynamic> _messages = [];
  bool _isLoading = true;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    // 1. Получаем ID текущего пользователя, чтобы понимать, свои ли это сообщения
    final profile = await _api.getProfile();
    if (profile != null && mounted) {
      _myUserId = profile['id'];
    }
    
    // 2. Загружаем историю
    await _loadMessages();
    
    // 3. Помечаем входящие как прочитанные
    if (mounted) {
      await _api.markMessagesAsRead(widget.meetingId);
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    final msgs = await _api.getMeetingMessages(widget.meetingId);
    if (mounted) {
      setState(() {
        _messages = msgs ?? [];
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final success = await _api.sendMessage(widget.meetingId, text);
    if (success && mounted) {
      _textController.clear();
      await _loadMessages();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить сообщение'), backgroundColor: Colors.redAccent),
      );
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
              backgroundColor: Colors.black.withOpacity(0.3),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.opponentName,
                    style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'По поводу: ${widget.meetingTitle}',
                    style: GoogleFonts.montserrat(color: const Color(0xFFD4AF37), fontSize: 10, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: BackgroundPattern(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
                  : _messages.isEmpty
                      ? Center(
                          child: Text(
                            'Пока нет сообщений. Напишите первым! 💬', 
                            style: GoogleFonts.montserrat(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.fromLTRB(
                            16, // Слева
                            MediaQuery.of(context).padding.top + kToolbarHeight + 16, // Сверху: статус-бар + высота AppBar + воздух
                            16, // Справа
                            MediaQuery.of(context).padding.bottom + 16, // Снизу: home-индикатор телефона + воздух
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            return _buildMessageBubble(_messages[index]);
                          },
                        ),
            ),
            // Поле ввода
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                border: Border(top: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: GoogleFonts.montserrat(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Сообщение...',
                        hintStyle: GoogleFonts.montserrat(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20), 
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFD4AF37),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send, color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    // Определяем, своё ли это сообщение
    final bool isMe = msg['sender_id'] == _myUserId;
    final timeStr = DateFormat('HH:mm').format(DateTime.parse(msg['created_at']));

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFD4AF37) : Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
          ),
          border: isMe ? null : Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg['text'],
              style: GoogleFonts.montserrat(
                color: isMe ? Colors.black : Colors.white,
                fontSize: 14,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: GoogleFonts.montserrat(
                color: isMe ? Colors.black54 : Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}