import 'package:flutter/material.dart';

class AppTheme {
  static const _background = Color(0xFF081212);
  static const _surface = Color(0xFF102222);
  static const _accent = Color(0xFF0DF2F2);
  static const _error = Color(0xFFFF4D4D);
  static const _textPrimary = Color(0xFFEAF9F9);
  static const _textSecondary = Color(0xFF8BA3A3);

  static ThemeData get dark {
    final scheme = const ColorScheme.dark(
      primary: _accent,
      secondary: _accent,
      surface: _surface,
      error: _error,
      onPrimary: _background,
      onSurface: _textPrimary,
      onError: _textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Space Grotesk',
      colorScheme: scheme,
      scaffoldBackgroundColor: _background,
      cardColor: _surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xCC081212),
        foregroundColor: _textPrimary,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x80102222),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x220DF2F2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x220DF2F2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accent, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: _background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: _textPrimary),
        bodySmall: TextStyle(color: _textSecondary),
        titleMedium: TextStyle(
          color: _textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        headlineSmall: TextStyle(color: _textPrimary, fontWeight: FontWeight.w800),
      ),
      focusColor: _accent,
    );
  }
}
