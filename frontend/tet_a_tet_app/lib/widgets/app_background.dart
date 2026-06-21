import 'package:flutter/material.dart';
import 'background_pattern.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Проверяем, активна ли премиум (золотая) тема
    final isPremium = theme.primaryColor == const Color(0xFFD4AF37);

    if (isPremium) {
      // В золотой теме добавляем красивый узор!
      return BackgroundPattern(child: child);
    }
    
    // В базовой теме оставляем чистый тёмный фон
    return child;
  }
}