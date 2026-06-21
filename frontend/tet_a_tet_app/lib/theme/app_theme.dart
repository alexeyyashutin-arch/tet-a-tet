import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // 🍷 Базовая тема: Тёмный бургунди + Бежевый (белое вино)
  static ThemeData get basicTheme {
    const beige = Color(0xFFF5F1E8); // 🆕 Бежевый (белое вино) — основной цвет!
    const beigeDark = Color(0xFFD4C5B0); // 🆕 Тёмно-бежевый для рамок и неактивных элементов
    const burgundy = Color(0xFF722F37); // Классический бургунди для рамок карточек
    const veryDarkBurgundy = Color(0xFF1A0508); // Почти чёрный бургунди для фона
    const darkCard = Color(0xFF2A0A0E); // Чуть светлее фона для карточек

    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: beige, // 🆕 Теперь основной цвет — бежевый!
      scaffoldBackgroundColor: veryDarkBurgundy,
      
      textTheme: GoogleFonts.montserratTextTheme(
        const TextTheme(
          bodyLarge: TextStyle(color: beige, fontSize: 16),
          bodyMedium: TextStyle(color: beigeDark, fontSize: 14),
          titleLarge: TextStyle(color: beige, fontSize: 20, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: beige, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: veryDarkBurgundy.withValues(alpha: 0.95),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.montserrat(
          color: beige, // 🆕 Заголовок AppBar теперь бежевый
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.0,
        ),
        iconTheme: const IconThemeData(color: beige), // 🆕 Иконки в AppBar бежевые
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: beige, //  Кнопки бежевые
          foregroundColor: veryDarkBurgundy, //  Текст на кнопках тёмный (для контраста)
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
      ),
      
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: burgundy, width: 1), // 🆕 Рамки карточек классического бургунди
        ),
      ),
      
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return beige;
          }
          return Colors.grey;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return beige.withValues(alpha: 0.5);
          }
          return Colors.grey.withValues(alpha: 0.3);
        }),
      ),
      
      iconTheme: const IconThemeData(color: beige), //  Все иконки по умолчанию бежевые
      
      dividerColor: burgundy.withValues(alpha: 0.3),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: burgundy, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: burgundy.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: beige, width: 1.5), // 🆕 Фокус на поле ввода — бежевый
        ),
      ),
    );
  }

  // 👑 Премиум тема: Золото + Чёрный (наша текущая)
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
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return gold;
          }
          return Colors.grey;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return gold.withValues(alpha: 0.5);
          }
          return Colors.grey.withValues(alpha: 0.3);
        }),
      ),
      
      iconTheme: const IconThemeData(color: gold),
      
      dividerColor: Colors.white.withValues(alpha: 0.05),
    );
  }
}