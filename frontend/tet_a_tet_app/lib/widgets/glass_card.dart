import 'dart:ui';
import 'package:flutter/material.dart';

/// 👑 Универсальный стеклянный виджет с размытием фона
/// Отвечает только за визуальный стиль (blur, рамка, фон).
/// Отступы (padding) задаются локально в каждом экране для гибкости!
class GlassCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double blurSigma;
  final double borderOpacity;
  final double backgroundOpacity;
  final EdgeInsetsGeometry? margin;
  final Gradient? gradient;

  const GlassCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(0), // 🆕 По умолчанию без отступов!
    this.borderRadius = 16,
    this.blurSigma = 3,
    this.borderOpacity = 0.2,
    this.backgroundOpacity = 0.05,
    this.margin,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: margin,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: gradient == null 
                  ? Colors.white.withValues(alpha: backgroundOpacity)
                  : null,
              gradient: gradient,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: theme.primaryColor.withValues(alpha: borderOpacity),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}