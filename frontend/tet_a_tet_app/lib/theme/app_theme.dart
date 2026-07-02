import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // 👑 Наша фирменная золотая тема — золото + чёрный
  static ThemeData get premiumTheme {
    const gold = Color(0xFFD4AF37);
    const goldLight = Color(0xFFFFD700);
    const black = Colors.black;
    const darkGrey = Color(0xFF1E1E1E);

    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: gold,
      scaffoldBackgroundColor: black,
      
      textTheme: GoogleFonts.montserratTextTheme(
        const TextTheme(
          bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
          bodyMedium: TextStyle(color: Colors.white, fontSize: 14),
          titleLarge: TextStyle(color: gold, fontSize: 20, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: gold, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: black.withValues(alpha: 0.3),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.montserrat(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.0,
        ),
        iconTheme: const IconThemeData(color: gold),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          shadowColor: gold.withValues(alpha: 0.4),
        ),
      ),
      
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.05),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: gold.withValues(alpha: 0.2), width: 1),
        ),
      ),
      
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return gold;
          }
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return gold.withValues(alpha: 0.5);
          }
          return Colors.grey.withValues(alpha: 0.3);
        }),
      ),
      
      iconTheme: const IconThemeData(color: gold),
      
      dividerColor: Colors.white.withValues(alpha: 0.05),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: gold.withValues(alpha: 0.3), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: gold.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gold, width: 1.5),
        ),
      ),
    );
  }
}