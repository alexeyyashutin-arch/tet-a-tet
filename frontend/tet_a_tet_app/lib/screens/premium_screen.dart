import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_background.dart';
import '../widgets/glass_card.dart';

/// 💎 Экран «Премиум-подписка»
///
/// Пока это заглушка — в будущем здесь будут:
/// - Описание преимуществ премиума (Клубничка, эксклюзивные функции)
/// - Выбор тарифа
/// - Платёжный шлюз
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

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
              backgroundColor:
                  theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
              elevation: 0,
              centerTitle: true,
              title: Text(
                'ПРЕМИУМ',
                style: GoogleFonts.montserrat(
                  color: theme.primaryColor,
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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GlassCard(
              padding: const EdgeInsets.all(32),
              borderOpacity: 0.5,
              children: [
                Icon(
                  Icons.workspace_premium,
                  color: theme.primaryColor,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  '🍓 Премиум-подписка',
                  style: GoogleFonts.montserrat(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Здесь скоро появится возможность оформить подписку\n'
                  'и открыть доступ к разделу «Клубничка» 😏',
                  style: GoogleFonts.montserrat(
                    color:
                        theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Icon(
                  Icons.construction,
                  color:
                      theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'В разработке...',
                  style: GoogleFonts.montserrat(
                    color:
                        theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}