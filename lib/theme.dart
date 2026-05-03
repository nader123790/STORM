import 'package:flutter/material.dart';

/// ==========================================
/// Storm Café — Premium Dark Café Theme
/// Professional Material 3 Theme
/// ==========================================
class CafeTheme {
  CafeTheme._();

  // ── Core palette (extracted from logo) ──
  static const Color darkBg = Color(0xFF000000);
  static const Color surface = Color(0xFF2E1F10);
  static const Color primaryBrown = Color(0xFF5F3814);
  static const Color secondaryBrown = Color(0xFF987B5C);
  static const Color accent = Color(0xFFC49A6D);
  static const Color mutedText = Color(0xFF65533E);
  static const Color textMain = Color(0xFFF5E6D3);
  static const Color border = Color(0x40C49A6D);

  // ── Extended palette ──
  static const Color deepBrown = Color(0xFF1A0F05);
  static const Color cardBg = Color(0xFF231507);
  static const Color inputBg = Color(0xFF1C1208);
  static const Color hoverBrown = Color(0xFF7A4D2A);
  static const Color accentGold = Color(0xFFD4A96A);

  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE53935);

  // ── Modern helper colors ──
  static const Color outline = Color(0x55C49A6D);
  static const Color disabled = Color(0xFF3A2A1B);
  static const Color shadow = Color(0xCC000000);

  // ── Radius system ──
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

  // ── Text theme (Premium Cairo Styling) ──
  static const TextTheme textTheme = TextTheme(
    headlineLarge: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      color: textMain,
      letterSpacing: 0.2,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      color: textMain,
    ),
    headlineSmall: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: textMain,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: textMain,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: textMain,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: textMain,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: textMain,
      height: 1.6,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: textMain,
      height: 1.6,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: mutedText,
      height: 1.5,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: textMain,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: textMain,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: mutedText,
    ),
  );

  // ── ThemeData ──
  static ThemeData get themeData => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBg,
        fontFamily: 'Cairo',

        // smooth ripple
        splashColor: accent.withValues(alpha: 0.12),
        highlightColor: accent.withValues(alpha: 0.06),

        // main scheme
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

        // typography
        textTheme: textTheme,

        // icons
        iconTheme: const IconThemeData(
          color: accent,
          size: 22,
        ),

        // AppBar
        appBarTheme: AppBarTheme(
          backgroundColor: surface,
          foregroundColor: textMain,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: textTheme.titleLarge,
          iconTheme: const IconThemeData(color: accent),
        ),

        // Cards
        cardTheme: CardTheme(
          color: cardBg.withValues(alpha: 0.92),
          elevation: 0,
          shadowColor: shadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
            side: BorderSide(color: outline.withValues(alpha: 0.25)),
          ),
        ),

        // Divider
        dividerTheme: DividerThemeData(
          color: outline.withValues(alpha: 0.25),
          thickness: 1,
        ),

        // Bottom navigation
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: surface,
          selectedItemColor: accent,
          unselectedItemColor: mutedText.withValues(alpha: 0.85),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: textTheme.labelSmall,
          unselectedLabelStyle: textTheme.labelSmall,
        ),

        // Buttons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBrown,
            foregroundColor: textMain,
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
            ),
            textStyle: textTheme.labelLarge,
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            side: BorderSide(color: outline.withValues(alpha: 0.55)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
            ),
            textStyle: textTheme.labelLarge,
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: accent,
            textStyle: textTheme.labelLarge,
          ),
        ),

        // Inputs
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: inputBg.withValues(alpha: 0.95),
          hintStyle: TextStyle(color: mutedText.withValues(alpha: 0.7)),
          labelStyle: const TextStyle(color: accent),
          prefixIconColor: accent.withValues(alpha: 0.9),
          suffixIconColor: mutedText.withValues(alpha: 0.9),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: BorderSide(color: outline.withValues(alpha: 0.25)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: BorderSide(color: outline.withValues(alpha: 0.25)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: BorderSide(color: accent.withValues(alpha: 0.8)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: BorderSide(color: error.withValues(alpha: 0.7)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: BorderSide(color: error),
          ),
        ),

        // Chips
        chipTheme: ChipThemeData(
          backgroundColor: cardBg.withValues(alpha: 0.8),
          selectedColor: accent.withValues(alpha: 0.25),
          disabledColor: disabled,
          labelStyle: textTheme.labelMedium,
          secondaryLabelStyle: textTheme.labelMedium,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            side: BorderSide(color: outline.withValues(alpha: 0.25)),
          ),
        ),

        // Dialog
        dialogTheme: DialogTheme(
          backgroundColor: cardBg.withValues(alpha: 0.98),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
            side: BorderSide(color: outline.withValues(alpha: 0.25)),
          ),
          titleTextStyle: textTheme.titleLarge,
          contentTextStyle: textTheme.bodyMedium,
        ),

        // SnackBar
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: cardBg.withValues(alpha: 0.95),
          contentTextStyle: textTheme.bodyMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),

        // Tooltip
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: cardBg.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(radiusSm),
            border: Border.all(color: outline.withValues(alpha: 0.2)),
          ),
          textStyle: textTheme.bodySmall,
        ),

        // Popup menus
        popupMenuTheme: PopupMenuThemeData(
          color: cardBg.withValues(alpha: 0.98),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            side: BorderSide(color: outline.withValues(alpha: 0.25)),
          ),
          textStyle: textTheme.bodyMedium,
        ),
      );
}
