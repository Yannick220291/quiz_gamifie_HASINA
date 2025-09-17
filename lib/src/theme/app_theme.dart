import 'package:flutter/material.dart';

class AppTheme {
  static const _neonBlue = Color(0xFF00D4FF);
  static const _neonPurple = Color(0xFF7B00FF);
  static const _darkBackground = Color(0xFF0A0E21);

  static final lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _neonBlue,
      brightness: Brightness.light,
      primary: _neonBlue,
      secondary: _neonPurple,
      surface: Colors.white,
      background: Colors.grey[100],
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        fontFamily: 'Orbitron',
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 5,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: _neonBlue,
        foregroundColor: Colors.white,
        shadowColor: _neonBlue.withOpacity(0.5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.95),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _neonBlue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: TextStyle(color: Colors.grey[600]),
    ),
    scaffoldBackgroundColor: Colors.white,
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _neonBlue,
      brightness: Brightness.dark,
      primary: _neonBlue,
      secondary: _neonPurple,
      surface: _darkBackground,
      background: _darkBackground,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        fontFamily: 'Orbitron',
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 5,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: _neonBlue,
        foregroundColor: Colors.white,
        shadowColor: _neonBlue.withOpacity(0.5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[800]!.withOpacity(0.95),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _neonBlue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: TextStyle(color: Colors.grey[400]),
    ),
    scaffoldBackgroundColor: _darkBackground,
  );
}