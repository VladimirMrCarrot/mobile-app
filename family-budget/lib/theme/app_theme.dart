// lib/theme/app_theme.dart
//
// Дизайн-система застосунку.
//
// Темна тема (основна):
//   Background : #13131F  (як у ER-діаграмі)
//   Surface    : #1E1E2E
//   Card       : #252535
//   Primary    : #6C63FF  (фіолетовий акцент)
//   Income     : #4CAF50  (зелений)
//   Expense    : #F44336  (червоний)
//   Transfer   : #FF9800  (жовтогарячий)
//
// Акцентні кольори категорій (для чіпів і графіків):
//   використовуються в CategoryColors.forId(categoryId)

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Палітра кольорів
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AppColors {
  // Фони (темна тема)
  static const darkBackground = Color(0xFF13131F);
  static const darkSurface = Color(0xFF1E1E2E);
  static const darkCard = Color(0xFF252535);

  // Фони (світла тема)
  static const lightBackground = Color(0xFFF5F5F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFF0F0F5);

  // Акцент
  static const primary = Color(0xFF6C63FF);
  static const primaryVariant = Color(0xFF4B44CC);
  static const secondary = Color(0xFF03DAC6);

  // Семантичні кольори транзакцій
  static const income = Color(0xFF4CAF50);
  static const expense = Color(0xFFF44336);
  static const transfer = Color(0xFFFF9800);
  static const unknown = Color(0xFF9E9E9E); // категорія '?'

  // Текст
  static const textPrimary = Color(0xFFE8E8F0);
  static const textSecondary = Color(0xFF9E9EB8);
  static const textDisabled = Color(0xFF5A5A7A);

  // Роздільники
  static const divider = Color(0xFF2E2E42);
}

// ─────────────────────────────────────────────────────────────────────────────
// Кольори категорій (22 категорії + '?')
// Індекси відповідають порядку seed-даних у DatabaseHelper
// ─────────────────────────────────────────────────────────────────────────────

abstract final class CategoryColors {
  static const _palette = [
    Color(0xFF4CAF50), // Продукти
    Color(0xFF2196F3), // Комуналка
    Color(0xFF9C27B0), // Батьки Ф
    Color(0xFFBA68C8), // Батьки С
    Color(0xFFCE93D8), // Батьки Ф зд
    Color(0xFFE1BEE7), // Батьки С зд
    Color(0xFF8BC34A), // ЗП
    Color(0xFFFFEB3B), // Таксі
    Color(0xFFFF5722), // Здоров'я
    Color(0xFFE91E63), // Косметика
    Color(0xFFF06292), // Краса
    Color(0xFF00BCD4), // Побут
    Color(0xFF3F51B5), // Освіта
    Color(0xFF009688), // Відпочинок
    Color(0xFFF44336), // Свята
    Color(0xFFFF9800), // Подарунки
    Color(0xFF795548), // Бува (собака)
    Color(0xFF607D8B), // Благо
    Color(0xFF4DB6AC), // Кешбек
    Color(0xFFEF5350), // Кредит
    Color(0xFF26A69A), // Тімур
    Color(0xFF78909C), // Інше
    Color(0xFF9E9E9E), // ?  (службова)
  ];

  /// Повертає колір для категорії за її числовим id (1-based).
  /// Якщо id поза діапазоном — повертає [AppColors.unknown].
  static Color forId(int categoryId) {
    final idx = categoryId - 1;
    if (idx < 0 || idx >= _palette.length) return AppColors.unknown;
    return _palette[idx];
  }

  /// Повертає колір для категорії за її назвою (fallback).
  static Color forName(String name) {
    const mapping = <String, Color>{
      'Продукти': Color(0xFF4CAF50),
      'Комуналка': Color(0xFF2196F3),
      'Батьки Ф': Color(0xFF9C27B0),
      'Батьки С': Color(0xFFBA68C8),
      'Батьки Ф зд': Color(0xFFCE93D8),
      'Батьки С зд': Color(0xFFE1BEE7),
      'ЗП': Color(0xFF8BC34A),
      'Таксі': Color(0xFFFFEB3B),
      "Здоров'я": Color(0xFFFF5722),
      'Косметика': Color(0xFFE91E63),
      'Краса': Color(0xFFF06292),
      'Побут': Color(0xFF00BCD4),
      'Освіта': Color(0xFF3F51B5),
      'Відпочинок': Color(0xFF009688),
      'Свята': Color(0xFFF44336),
      'Подарунки': Color(0xFFFF9800),
      'Бува': Color(0xFF795548),
      'Благо': Color(0xFF607D8B),
      'Кешбек': Color(0xFF4DB6AC),
      'Кредит': Color(0xFFEF5350),
      'Тімур': Color(0xFF26A69A),
      'Інше': Color(0xFF78909C),
      '?': Color(0xFF9E9E9E),
    };
    return mapping[name] ?? AppColors.unknown;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Тема застосунку
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AppTheme {
  // ── Темна тема ─────────────────────────────────────────────────────────────
  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      brightness: Brightness.dark,
      surface: AppColors.darkBackground,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      onSurface: AppColors.textPrimary,
      onPrimary: Colors.white,
      error: AppColors.expense,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBackground,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // BottomNavigationBar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),

      // FilledButton
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      ),

      // Chip
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.darkCard,
        selectedColor: AppColors.primaryVariant,
        labelStyle: TextStyle(color: AppColors.textPrimary, fontSize: 12),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),

      // InputDecoration
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: AppColors.textDisabled),
        labelStyle: TextStyle(color: AppColors.textSecondary),
      ),

      // Typography
      textTheme: const TextTheme(
        headlineLarge:
            TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        headlineMedium:
            TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleLarge:
            TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleMedium:
            TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        bodySmall: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        labelLarge:
            TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(color: AppColors.textSecondary, fontSize: 11),
      ),
    );
  }

  // ── Світла тема ────────────────────────────────────────────────────────────
  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      brightness: Brightness.light,
      surface: AppColors.lightBackground,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      onSurface: Color(0xFF1A1A2E),
      onPrimary: Colors.white,
      error: AppColors.expense,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: Color(0xFF1A1A2E),
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
