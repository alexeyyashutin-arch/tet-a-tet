import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/background_pattern.dart';

class MeetingDetailScreen extends StatelessWidget {
  final Map<String, dynamic> meeting;

  const MeetingDetailScreen({super.key, required this.meeting});

  @override
  Widget build(BuildContext context) {
    final username = meeting['creator_username'] ?? 'Аноним';
    final age = meeting['creator_age'];
    final nameWithAge = age != null ? '$username, $age' : username;
    final financeText = _getFinanceText(meeting['finance']);
    final dateStr = _formatDate(meeting['meeting_date']);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'ПОДРОБНОСТИ',
          style: GoogleFonts.montserrat(
            color: const Color(0xFFD4AF37),
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 20,
          ),
        ),
      ),
      body: BackgroundPattern(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Creator card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFF252525),
                      backgroundImage: meeting['creator_avatar_url'] != null
                          ? CachedNetworkImageProvider('${ApiService.baseUrl}${meeting['creator_avatar_url']}')
                          : null,
                      child: meeting['creator_avatar_url'] == null
                          ? const Icon(Icons.person, color: Color(0xFFD4AF37), size: 30)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nameWithAge,
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          financeText,
                          style: GoogleFonts.montserrat(
                            color: const Color(0xFFD4AF37),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Meeting title
              Text(
                meeting['title'],
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 20),

              // Info rows
              _buildInfoRow(Icons.calendar_today, '$dateStr в ${meeting['meeting_time']}'),
              if (meeting['location'] != null && meeting['location'].toString().isNotEmpty)
                _buildInfoRow(Icons.location_on, meeting['location']),

              // Description
              if (meeting['description'] != null && meeting['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'ОПИСАНИЕ',
                  style: GoogleFonts.montserrat(
                    color: const Color(0xFFD4AF37),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  meeting['description'],
                  style: GoogleFonts.montserrat(
                    color: Colors.grey.shade300,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],

              // Partner wishes
              if (meeting['partner_wishes'] != null && meeting['partner_wishes'].toString().isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'ПОЖЕЛАНИЯ К СПУТНИЦЕ',
                  style: GoogleFonts.montserrat(
                    color: const Color(0xFFD4AF37),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.2)),
                  ),
                  child: Text(
                    meeting['partner_wishes'],
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // Response button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                    shadowColor: const Color(0xFFD4AF37).withOpacity(0.5),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Твой отклик отправлен! Жди ответа, $username! 💕'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: Text(
                    'ОТКЛИКНУТЬСЯ НА ВСТРЕЧУ',
                    style: GoogleFonts.montserrat(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFD4AF37), size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.montserrat(
              color: Colors.grey.shade300,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  String _getFinanceText(String finance) {
    switch (finance) {
      case 'self':
        return 'Плачу сам';
      case 'split':
        return 'Платим поровну';
      case 'partner':
        return 'Платит партнёр';
      case 'none':
        return 'Бесплатно';
      default:
        return finance;
    }
  }

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    const months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return '${date.day} ${months[date.month - 1]}';
  }
}