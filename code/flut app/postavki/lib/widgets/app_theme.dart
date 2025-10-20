import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: Color(0xFF667eea),
      colorScheme: ColorScheme.light(
        primary: Color(0xFF667eea),
        secondary: Color(0xFF764ba2),
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF667eea),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF667eea),
          foregroundColor: Colors.white,
          minimumSize: Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        bodyMedium: TextStyle(fontSize: 16, color: Colors.black54),
      ),
    );
  }

  // Можно добавить темную тему
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      primaryColor: Color(0xFF667eea),
      // ... остальные настройки для темной темы
    );
  }
}
