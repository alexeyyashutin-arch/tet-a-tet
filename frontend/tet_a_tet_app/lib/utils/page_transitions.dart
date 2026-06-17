import 'package:flutter/material.dart';

/// 🆕 Универсальный плавный переход между экранами (Fade + Slide)
PageRouteBuilder createFadeSlideTransition(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      var curve = Curves.easeInOutCubic;
      var tween = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: curve),
      );
      
      var slideTween = Tween<Offset>(
        begin: const Offset(0.05, 0.0), // Лёгкий сдвиг вправо
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: curve));
      
      return SlideTransition(
        position: slideTween,
        child: FadeTransition(
          opacity: tween,
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}