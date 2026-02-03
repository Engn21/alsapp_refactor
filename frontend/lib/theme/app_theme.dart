import 'package:flutter/material.dart';

// Centralized theme configuration for the app.
class AppTheme {
  // Brand color palette.
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color accent = Color(0xFF388E3C);
  static const Color bg = Color(0xFFE8F5E9);

  // Light theme definition used by MaterialApp.
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: primary)
          .copyWith(primary: primary, secondary: accent),
      // App bar styling for consistent headers.
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      // Default text field styles.
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: const TextStyle(color: primaryDark),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: primary.withOpacity(.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primary.withOpacity(.4)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: primaryDark, width: 1.6),
        ),
      ),
      // Primary button styling.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      // Card appearance across the app.
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
