import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFFFFB800);
  static const navy = Color(0xFF082840);
  static const green = Color(0xFF00BE78);
  static const orange = Color(0xFFFFB800);
  static const red = Color(0xFFFA463C);
  static const ink = Color(0xFF0B2A3C);
  static const field = Color(0xFFF1F5F7);
}

class AppTheme {
  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);

  static ThemeData _base(Brightness b) {
    final isDark = b == Brightness.dark;
    final bg = isDark ? const Color(0xFF082840) : const Color(0xFFF7F9FA);
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: b)
        .copyWith(surface: isDark ? const Color(0xFF103050) : Colors.white);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? bg : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.ink,
        titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF103050) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: isDark ? AppColors.navy : Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
