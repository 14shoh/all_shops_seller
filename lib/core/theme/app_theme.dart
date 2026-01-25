import 'package:flutter/material.dart';

/// Единая тема приложения с консистентными шрифтами и стилями
class AppTheme {
  // Цветовая палитра
  static const Color primaryColor = Color(0xFF6366F1);
  static const Color secondaryColor = Color(0xFF8B5CF6);
  static const Color successColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);
  
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  
  static const Color backgroundPrimary = Color(0xFFF8FAFC);
  static const Color backgroundSecondary = Color(0xFFF1F5F9);
  static const Color surfaceColor = Colors.white;
  static const Color borderColor = Color(0xFFE2E8F0);

  // Единые размеры отступов
  static const double paddingXS = 8.0;
  static const double paddingSM = 12.0;
  static const double paddingMD = 16.0;
  static const double paddingLG = 20.0;
  static const double paddingXL = 24.0;
  
  // Единые размеры скругления
  static const double radiusSM = 12.0;
  static const double radiusMD = 16.0;
  static const double radiusLG = 20.0;
  static const double radiusXL = 24.0;

  /// Создает единую тему приложения
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      
      // Единая типографика
      textTheme: const TextTheme(
        // Заголовки
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: textPrimary,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: textPrimary,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: textPrimary,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.3,
          height: 1.3,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.3,
          height: 1.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.3,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.2,
          height: 1.4,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.2,
          height: 1.4,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 0,
          height: 1.4,
        ),
        // Основной текст
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          letterSpacing: 0,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          letterSpacing: 0,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          letterSpacing: 0,
          height: 1.5,
        ),
        // Второстепенный текст
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textSecondary,
          letterSpacing: 0.1,
          height: 1.4,
        ),
        labelMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textSecondary,
          letterSpacing: 0.1,
          height: 1.4,
        ),
        labelSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textTertiary,
          letterSpacing: 0.5,
          height: 1.4,
        ),
      ),
      
      // Стили для полей ввода
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: paddingMD, vertical: paddingMD),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textTertiary,
        ),
        hintStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: textTertiary,
        ),
      ),
      
      // Стили для карточек
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLG),
          side: const BorderSide(color: borderColor, width: 1),
        ),
        color: surfaceColor,
      ),
      
      scaffoldBackgroundColor: backgroundPrimary,
    );
  }

  /// Стили для заголовков экранов
  static TextStyle get screenTitle => const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w900,
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  /// Стили для подзаголовков экранов
  static TextStyle get screenSubtitle => const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    height: 1.3,
  );

  /// Стили для названий карточек
  static TextStyle get cardTitle => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.2,
    height: 1.4,
  );

  /// Стили для описаний карточек
  static TextStyle get cardSubtitle => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    height: 1.5,
  );

  /// Стили для цен
  static TextStyle get priceText => const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: successColor,
    height: 1.2,
  );

  /// Стили для меток (labels)
  static TextStyle get labelText => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: textTertiary,
    letterSpacing: 1.2,
    height: 1.4,
  );
}
