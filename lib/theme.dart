import 'package:flutter/material.dart';

/// ==========================================
/// Storm Café — Premium Dark Café Theme
/// Material 3 | Optimized
/// ==========================================
class CafeTheme {
  CafeTheme._();

  // ── Core palette ──
  static const Color darkBg          = Color(0xFF000000);
  static const Color surface         = Color(0xFF2E1F10);
  static const Color primaryBrown    = Color(0xFF5F3814);
  static const Color secondaryBrown  = Color(0xFF987B5C);
  static const Color accent          = Color(0xFFC49A6D);
  static const Color mutedText       = Color(0xFF65533E);
  static const Color textMain        = Color(0xFFF5E6D3);
  static const Color border          = Color(0x40C49A6D);

  // ── Extended palette ──
  static const Color deepBrown  = Color(0xFF1A0F05);
  static const Color cardBg     = Color(0xFF231507);
  static const Color inputBg    = Color(0xFF1C1208);
  static const Color hoverBrown = Color(0xFF7A4D2A);
  static const Color accentGold = Color(0xFFD4A96A);

  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error   = Color(0xFFE53935);

  static const Color outline  = Color(0x55C49A6D);
  static const Color disabled = Color(0xFF3A2A1B);
  static const Color shadow   = Color(0xCC000000);

  // ── Radius ──
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 22;

  // ── Gradients ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryBrown, hoverBrown],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, secondaryBrown],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [surface, deepBrown, Color(0xFF0D0804)],
  );

  static const LinearGradient inBasketGradient = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0xFF1A2A10), Color(0xFF0D1A05), Color(0xFF060804)],
  );

  // ── Text Theme ──
  static const TextTheme textTheme = TextTheme(
    headlineLarge:  TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: textMain, letterSpacing: 0.2),
    headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textMain),
    headlineSmall:  TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textMain),
    titleLarge:     TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textMain),
    titleMedium:    TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textMain),
    titleSmall:     TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textMain),
    bodyLarge:      TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textMain, height: 1.6),
    bodyMedium:     TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textMain, height: 1.6),
    bodySmall:      TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: mutedText, height: 1.5),
    labelLarge:     TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textMain),
    labelMedium:    TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMain),
    labelSmall:     TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: mutedText),
  );

  static ThemeData get themeData => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBg,
    fontFamily: 'Cairo',
    splashColor: Color(0x1FC49A6D),
    highlightColor: Color(0x0FC49A6D),

    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBrown,
      brightness: Brightness.dark,
      surface: surface,
      onSurface: textMain,
      primary: primaryBrown,
      onPrimary: textMain,
      secondary: secondaryBrown,
      onSecondary: textMain,
      error: error,
      onError: Colors.white,
    ),

    textTheme: textTheme,
    iconTheme: const IconThemeData(color: accent, size: 22),

    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: textMain,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: textTheme.titleLarge,
      iconTheme: const IconThemeData(color: accent),
    ),

    cardTheme: CardThemeData(
      color: Color(0xEB231507),
      elevation: 0,
      shadowColor: shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        side: BorderSide(color: Color(0x40C49A6D)),
      ),
    ),

    dividerTheme: const DividerThemeData(color: Color(0x40C49A6D), thickness: 1),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: accent,
      unselectedItemColor: Color(0xD965533E),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: textTheme.labelSmall,
      unselectedLabelStyle: textTheme.labelSmall,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBrown,
        foregroundColor: textMain,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        textStyle: textTheme.labelLarge,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: const BorderSide(color: Color(0x8CC49A6D)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        textStyle: textTheme.labelLarge,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        textStyle: textTheme.labelLarge,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color(0xF21C1208),
      hintStyle: const TextStyle(color: Color(0xB265533E)),
      labelStyle: const TextStyle(color: accent),
      prefixIconColor: Color(0xE6C49A6D),
      suffixIconColor: Color(0xE665533E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: Color(0x40C49A6D)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: Color(0x40C49A6D)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: Color(0xCCC49A6D)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: Color(0xB2E53935)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: error),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: Color(0xCC231507),
      selectedColor: Color(0x40C49A6D),
      disabledColor: disabled,
      labelStyle: textTheme.labelMedium,
      secondaryLabelStyle: textTheme.labelMedium,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        side: const BorderSide(color: Color(0x40C49A6D)),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: Color(0xFA231507),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        side: const BorderSide(color: Color(0x40C49A6D)),
      ),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Color(0xF2231507),
      contentTextStyle: textTheme.bodyMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: Color(0xF2231507),
        borderRadius: BorderRadius.circular(radiusSm),
        border: Border.all(color: Color(0x33C49A6D)),
      ),
      textStyle: textTheme.bodySmall,
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: Color(0xFA231507),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        side: const BorderSide(color: Color(0x40C49A6D)),
      ),
      textStyle: textTheme.bodyMedium,
    ),
  );
}
