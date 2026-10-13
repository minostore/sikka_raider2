import 'package:flutter/material.dart';

/// هوية سيكة: أسود #1A1A1A + أصفر #FFCC00 + أبيض، بطاقات دائرية الحواف.
class AppColors {
  static const primary = Color(0xFFFFCC00);
  static const navy = Color(0xFF1A1A1A); // خلفية التطبيق، ونص الأزرار الصفراء
  static const bg = Color(0xFF1A1A1A);
  static const card = Color(0xFF262626);
  static const border = Color(0xFF3D3D3D);
  static const green = Color(0xFF00BE78);
  static const orange = Color(0xFFFFCC00);
  static const red = Color(0xFFFA463C);
  static const ink = Color(0xFFF5F5F5); // لون النص الأساسي فوق البطاقات الداكنة
  static const field = Color(0xFF2E2E2E);
}

class AppTheme {
  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);

  static ThemeData _base(Brightness b) {
    final isDark = b == Brightness.dark;
    final bg = isDark ? AppColors.bg : const Color(0xFFF7F9FA);
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: b).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.navy,
      surface: isDark ? AppColors.card : Colors.white,
    );
    final radius = BorderRadius.circular(14);
    OutlineInputBorder ob(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: c, width: w));
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      dividerTheme: DividerThemeData(color: isDark ? AppColors.border : Colors.grey.shade300, thickness: 1),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? bg : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.navy,
        titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.navy),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.card : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: isDark ? AppColors.border : Colors.grey.shade200),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.field : Colors.white,
        border: ob(isDark ? AppColors.border : Colors.grey.shade300),
        enabledBorder: ob(isDark ? AppColors.border : Colors.grey.shade300),
        focusedBorder: ob(AppColors.primary, 1.6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.navy,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : AppColors.navy,
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: isDark ? AppColors.border : Colors.grey.shade400),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.card : Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.card : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.bg : Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((s) =>
            IconThemeData(color: s.contains(WidgetState.selected) ? AppColors.primary : Colors.white60)),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? AppColors.primary : Colors.white60)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
