import 'package:flutter/material.dart';

class AppTheme {
  static const Color brandGreen = Color(0xFF1F9D6E);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(seedColor: brandGreen);
    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);
    final nunitoTextTheme = base.textTheme.apply(
      fontFamily: 'Nunito',
      bodyColor: Colors.black87,
      displayColor: Colors.black87,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Nunito',
      textTheme: nunitoTextTheme,
      primaryTextTheme: nunitoTextTheme,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: const TextStyle(fontFamily: 'Nunito'),
        labelStyle: const TextStyle(fontFamily: 'Nunito'),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE3E7EE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE3E7EE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brandGreen,
          textStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}

