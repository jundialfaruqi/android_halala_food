import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static const String fontFamily = 'PlusJakartaSans';

  // Backwards compatibility alias jika ada yang memanggil AppTheme.primaryColor
  static const Color primaryColor = AppColors.brandPrimary;
  static const Color primaryDark = AppColors.brandPrimaryHover;
  static const Color secondaryColor = AppColors.brandEspresso;
  static const Color accentColor = AppColors.brandHoney;
  static const Color backgroundColor = AppColors.background;
  static const Color surfaceColor = AppColors.surface;
  static const Color errorColor = AppColors.error;
  static const Color successColor = AppColors.success;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandPrimary,
        primary: AppColors.brandPrimary,
        secondary: AppColors.brandEspresso,
        tertiary: AppColors.brandHoney,
        surface: AppColors.surface,
        error: AppColors.error,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.brandEspresso,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: AppColors.brandEspresso,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.brandWarmGray,
        ),
        hintStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.brandWarmGray,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      textTheme: ThemeData.light().textTheme.apply(
        fontFamily: fontFamily,
        bodyColor: AppColors.brandTextPrimary,
        displayColor: AppColors.brandEspresso,
      ).copyWith(
        headlineLarge: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.bold,
          color: AppColors.brandEspresso,
        ),
        headlineMedium: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.bold,
          color: AppColors.brandEspresso,
        ),
        titleLarge: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          color: AppColors.brandEspresso,
        ),
        bodyLarge: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.brandTextPrimary,
        ),
        bodyMedium: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.brandTextPrimary,
        ),
      ),
    );
  }
}
