import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF2E5A44),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFCBEAD7),
    onPrimaryContainer: Color(0xFF002111),
    secondary: Color(0xFF8B5E3C),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFFFDDB8),
    onSecondaryContainer: Color(0xFF2E1A03),
    tertiary: Color(0xFF3B6B55),
    onTertiary: Colors.white,
    error: Color(0xFFBA1A1A),
    onError: Colors.white,
    background: Color(0xFFFAF9F6),
    onBackground: Color(0xFF191C1A),
    surface: Color(0xFFFAF9F6),
    onSurface: Color(0xFF191C1A),
    surfaceVariant: Color(0xFFDDE5DF),
    onSurfaceVariant: Color(0xFF414945),
    outline: Color(0xFF717975),
  );

  static const _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF84CBB1),
    onPrimary: Color(0xFF003822),
    primaryContainer: Color(0xFF0F513A),
    onPrimaryContainer: Color(0xFFCBEAD7),
    secondary: Color(0xFFF7BD94),
    onSecondary: Color(0xFF512E11),
    secondaryContainer: Color(0xFF6E4525),
    onSecondaryContainer: Color(0xFFFFDDB8),
    tertiary: Color(0xFF9FD4B9),
    onTertiary: Color(0xFF053823),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    background: Color(0xFF121413),
    onBackground: Color(0xFFE1E3DF),
    surface: Color(0xFF121413),
    onSurface: Color(0xFFE1E3DF),
    surfaceVariant: Color(0xFF414945),
    onSurfaceVariant: Color(0xFFC1C9C3),
    outline: Color(0xFF8B938E),
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _lightColorScheme,
      scaffoldBackgroundColor: _lightColorScheme.background,
      appBarTheme: AppBarTheme(
        backgroundColor: _lightColorScheme.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: _lightColorScheme.onBackground,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: _lightColorScheme.onBackground),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _lightColorScheme.primary,
        foregroundColor: _lightColorScheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightColorScheme.surfaceVariant.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _lightColorScheme.primary, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _darkColorScheme,
      scaffoldBackgroundColor: _darkColorScheme.background,
      appBarTheme: AppBarTheme(
        backgroundColor: _darkColorScheme.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: _darkColorScheme.onBackground,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: _darkColorScheme.onBackground),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF1E211F),
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _darkColorScheme.primary,
        foregroundColor: _darkColorScheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkColorScheme.surfaceVariant.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _darkColorScheme.primary, width: 1.5),
        ),
      ),
    );
  }
}
