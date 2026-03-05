import 'package:flutter/material.dart';

class AppTheme {
  static const _background = Color(0xFF0B1426);
  static const _surface = Color(0xFF162544);
  static const _accent = Color(0xFF40C4FF);
  static const _error = Color(0xFFFF5252);
  static const _textPrimary = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFFB0BEC5);

  static ThemeData get dark {
    final scheme = const ColorScheme.dark(
      primary: _accent,
      surface: _surface,
      error: _error,
      onPrimary: _background,
      onSurface: _textPrimary,
      onError: _textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _background,
      cardColor: _surface,
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: _textPrimary),
        bodySmall: TextStyle(color: _textSecondary),
        titleMedium: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700),
      ),
      focusColor: _accent,
    );
  }
}
