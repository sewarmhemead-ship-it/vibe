import 'package:flutter/material.dart';

/// Global dark theme: same visuals regardless of system light/dark or locale.
ThemeData get vibeOrbitDarkTheme {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF448AFF),
    brightness: Brightness.dark,
  ).copyWith(
    surface: Colors.black,
    onSurface: Colors.white,
    primary: const Color(0xFF448AFF),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.black,
    dialogTheme: const DialogThemeData(
      backgroundColor: Color(0xFF121212),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF2A2A2A),
      contentTextStyle: const TextStyle(color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xE6000000),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIconColor: Colors.white70,
      suffixIconColor: Colors.white70,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF448AFF), width: 1.5),
      ),
    ),
  );
}

/// Higher-contrast dark theme (accessibility / long reading).
ThemeData get vibeOrbitDarkThemeHighContrast {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7C5CFC),
    brightness: Brightness.dark,
  ).copyWith(
    surface: const Color(0xFF050508),
    onSurface: const Color(0xFFF5F5F5),
    onSurfaceVariant: const Color(0xFFD8D8E0),
    outline: Colors.white60,
    outlineVariant: Colors.white38,
    primary: const Color(0xFF9B84FF),
    onPrimary: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF050508),
    dialogTheme: const DialogThemeData(
      backgroundColor: Color(0xFF16161C),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF2E2E36),
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xF20A0A10),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
      labelStyle: const TextStyle(color: Color(0xFFE8E8EE)),
      prefixIconColor: const Color(0xFFE0E0E8),
      suffixIconColor: const Color(0xFFE0E0E8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF6A6A78)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF6A6A78)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF9B84FF), width: 1.8),
      ),
    ),
  );
}
