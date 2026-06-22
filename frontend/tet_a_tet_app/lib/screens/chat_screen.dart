import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';
import '../widgets/app_background.dart';

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
  
  // 🆕 WebSocket
  WebSocketChannel? _channel;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    final profile = await _api.getProfile();
    if (profile != null && mounted) {
      _myUserId = profile['id'];
    }
    
    await _loadMessages();
    
    print('✅ [ЧАТ] Сообщения загружены, сейчас пометим как прочитанные...');
    if (mounted) {
      await _api.markMessagesAsRead(widget.meetingId);
    }
    
    // 🆕 Подключаем WebSocket для мгновенных сообщений
    _connectWebSocket();
  }

  // 🆕 Подключение к WebSocket
  Future<void> _connectWebSocket() async {
    try {
      final token = await _api.getToken(); // Получаем JWT токен
      if (token == null) {
        print('❌ [WebSocket] Не удалось получить токен');
        return;
      }

      // Формируем URL (замени localhost на свой IP, если тестируешь на телефоне)
      final wsUrl = 'ws://localhost:8000/ws/${widget.meetingId}?token=$token';
      print('🔌 [WebSocket] Подключаемся к: $wsUrl');
      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      await _channel!.ready;
      _isConnected = true;
      print('✅ [WebSocket] Подключено!');
      
      // Слушаем входящие сообщения
      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            print('📨 [WebSocket] Получено: $data');
            
            if (data['type'] == 'new_message') {
              // 🆕 Не добавляем свои собственные сообщения (они уже добавлены через REST)
              if (data['sender_id'] == _myUserId) {
                print('⏭️ [WebSocket] Пропускаем своё сообщение (уже добавлено)');
                return;
              }
              
              // Проверяем дубликаты
              final exists = _messages.any((m) => m['id'] == data['id']);
              if (!exists) {
                setState(() {
                  _messages.add(data);
                });
                _scrollToBottom();
              }
              
              // Помечаем как прочитанное
              _api.markMessagesAsRead(widget.meetingId);
            }
            else if (data['type'] == 'messages_read') {
              // Обновляем галочки прочтения
              setState(() {
                for (var msg in _messages) {
                  if (msg['sender_id'] == _myUserId) {
                    msg['is_read'] = true;
                  }
                }
              });
            }
          } catch (e) {
            print('❌ [WebSocket] Ошибка парсинга: $e');
          }
        },
        onError: (error) {
          print('❌ [WebSocket] Ошибка: $error');
          _isConnected = false;
        },
        onDone: () {
          print('🔴 [WebSocket] Соединение закрыто');
          _isConnected = false;
        },
      );
      
    } catch (e) {
      print('❌ [WebSocket] Ошибка подключения: $e');
      _isConnected = false;
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    final msgs = await _api.getMeetingMessages(widget.meetingId);
    
    print('🔍 [ЧАТ] Загруженные сообщения для встречи ${widget.meetingId}: $msgs');
    
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

    // 🆕 Сразу показываем сообщение в UI (оптимистичное обновление)
    final tempMessage = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'text': text,
      'sender_id': _myUserId,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    };
    
    setState(() {
      _messages.add(tempMessage);
    });
    _textController.clear();
    _scrollToBottom();

    // Отправляем через REST API
    final success = await _api.sendMessage(widget.meetingId, text);
    
    if (success && mounted) {
      // 🆕 Перезагружаем сообщения, чтобы получить реальные ID и данные
      await _loadMessages();
    } else if (mounted) {
      // Если не удалось отправить — убираем временное сообщение
      setState(() {
        _messages.removeWhere((m) => m['id'] == tempMessage['id']);
      });
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
              backgroundColor: Colors.black.withValues(alpha: 0.3),
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
              // 🆕 Индикатор подключения WebSocket
              actions: [
                if (_isConnected)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.circle, color: Colors.green, size: 10),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: AppBackground(
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
                            16,
                            MediaQuery.of(context).padding.top + kToolbarHeight + 16,
                            16,
                            MediaQuery.of(context).padding.bottom + 16,
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            return _buildMessageBubble(_messages[index]);
                          },
                        ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                border: Border(top: BorderSide(color: const Color(0xFFD4AF37).withValues(alpha: 0.3))),
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
                        fillColor: Colors.black.withValues(alpha: 0.3),
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
    final bool isMe = msg['sender_id'] == _myUserId;
    final bool isRead = msg['is_read'] ?? false;
    final timeStr = DateFormat('HH:mm').format(DateTime.parse(msg['created_at']));

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFD4AF37) : Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
          ),
          border: isMe ? null : Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: GoogleFonts.montserrat(
                    color: isMe ? Colors.black54 : Colors.grey,
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: isRead ? Colors.black : Colors.black54,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // 🆕 Закрываем WebSocket при выходе из экрана
    _channel?.sink.close();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}