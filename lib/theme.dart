import 'package:flutter/material.dart';

/// ==========================================
/// Storm Café — Premium Dark Café Theme
/// Based on logo color palette extraction
/// ==========================================
class CafeTheme {
  CafeTheme._();

  // ── Core palette (extracted from logo) ──
  static const Color darkBg         = Color(0xFF000000);
  static const Color surface        = Color(0xFF2E1F10);
  static const Color primaryBrown   = Color(0xFF5F3814);
  static const Color secondaryBrown = Color(0xFF987B5C);
  static const Color accent         = Color(0xFFC49A6D);
  static const Color mutedText      = Color(0xFF65533E);
  static const Color textMain       = Color(0xFFF5E6D3);
  static const Color border         = Color(0x40C49A6D); // rgba(196,154,109,0.25)

  // ── Extended palette ──
  static const Color deepBrown      = Color(0xFF1A0F05);
  static const Color cardBg         = Color(0xFF231507);
  static const Color inputBg        = Color(0xFF1C1208);
  static const Color hoverBrown     = Color(0xFF7A4D2A);
  static const Color accentGold     = Color(0xFFD4A96A);
  static const Color success        = Color(0xFF4CAF50);
  static const Color warning        = Color(0xFFFF9800);
  static const Color error          = Color(0xFFE53935);

  // ── Gradients ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF5F3814), Color(0xFF7A4D2A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFC49A6D), Color(0xFF987B5C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0xFF2E1F10), Color(0xFF1A0F05), Color(0xFF0D0804)],
  );

  static const LinearGradient inBasketGradient = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0xFF1A2A10), Color(0xFF0D1A05), Color(0xFF060804)],
  );

  // ── ThemeData ──
  static ThemeData get themeData => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBg,
    fontFamily: 'Cairo',
    splashColor: accent.withValues(alpha: 0.15),
    highlightColor: secondaryBrown.withValues(alpha: 0.1),
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBrown,
      brightness: Brightness.dark,
      surface: surface,
      onSurface: textMain,
      primary: primaryBrown,
      secondary: secondaryBrown,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      foregroundColor: textMain,
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: accent,
      unselectedItemColor: mutedText,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBrown,
        foregroundColor: textMain,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: mutedText.withValues(alpha: 0.7)),
    ),
  );
}
