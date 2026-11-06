import 'package:flutter/material.dart';

class AppTheme {
  // --- Brand Core Palette (Green & Gold Ecosystem) ---
  static const Color primaryGreen = Color(0xFF2D6A4F);     // Deep Emerald Green
  static const Color emeraldDark = Color(0xFF1B4332);      // Forest Emerald
  static const Color leafGreen = Color(0xFF52B788);        // Vibrant Organic Leaf
  static const Color brandGold = Color(0xFFD4AF37);        // Classic Organic Gold
  static const Color brandGoldLight = Color(0xFFF3E5AB);   // Soft Champagne Gold Accent
  static const Color brandGoldDark = Color(0xFFA67C1E);    // Rich Metallic Amber/Gold

  // --- Light Mode Colors ---
  static const Color bgLight = Color(0xFFFBFBF9);          // Warm Off-White / Ivory
  static const Color surfaceLight = Color(0xFFFFFFFF);     // Pure White Cards
  static const Color surfaceSubtleLight = Color(0xFFF4F6F4); // Subtle Surface
  static const Color textPrimaryLight = Color(0xFF1B2E24); // Deep Charcoal / Forest
  static const Color textSecondaryLight = Color(0xFF5A7064);
  static const Color borderLight = Color(0xFFE4E9E4);

  // --- Dark Mode Colors ---
  static const Color bgDark = Color(0xFF0E1712);           // Deep Charcoal / Dark Green
  static const Color surfaceDark = Color(0xFF16241C);      // Slightly lighter surface for cards
  static const Color surfaceSubtleDark = Color(0xFF1D2E24);
  static const Color textPrimaryDark = Color(0xFFECF3EE);   // High-contrast clean text
  static const Color textSecondaryDark = Color(0xFF98ACA0);
  static const Color borderDark = Color(0xFF24382B);

  // --- Helper Getters / Design Tokens ---
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color cardColor(BuildContext context) =>
      isDark(context) ? surfaceDark : surfaceLight;

  static Color cardSubtleColor(BuildContext context) =>
      isDark(context) ? surfaceSubtleDark : surfaceSubtleLight;

  static Color borderColor(BuildContext context) =>
      isDark(context) ? borderDark : borderLight;

  static Color goldAccent(BuildContext context) =>
      isDark(context) ? brandGold : brandGoldDark;

  static Color primaryAction(BuildContext context) =>
      isDark(context) ? leafGreen : primaryGreen;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? textPrimaryDark : textPrimaryLight;

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? textSecondaryDark : textSecondaryLight;

  // --- Design System: Typography Helpers ---
  static TextStyle pageTitleStyle(BuildContext context) => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.3,
        color: textPrimary(context),
      );

  static TextStyle sectionHeadingStyle(BuildContext context) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.2,
        color: textPrimary(context),
      );

  static TextStyle cardTitleStyle(BuildContext context) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary(context),
      );

  static TextStyle bodyStyle(BuildContext context) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.normal,
        color: textPrimary(context),
      );

  static TextStyle descriptionStyle(BuildContext context) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: textSecondary(context),
        height: 1.35,
      );

  static TextStyle captionStyle(BuildContext context) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: textSecondary(context),
      );

  static TextStyle priceStyle(
    BuildContext context, {
    double size = 16,
    bool isGold = true,
  }) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.bold,
        color: isGold
            ? (isDark(context) ? brandGoldLight : brandGoldDark)
            : textPrimary(context),
      );

  // --- Design System: Input Decoration Helper ---
  static InputDecoration inputDecoration(
    BuildContext context, {
    String? hintText,
    String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final dark = isDark(context);
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: dark ? surfaceSubtleDark : surfaceSubtleLight,
      hintStyle: TextStyle(
        color: textSecondary(context).withValues(alpha: 0.7),
        fontSize: 13,
      ),
      labelStyle: TextStyle(
        color: textSecondary(context),
        fontSize: 13,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: dark ? borderDark : borderLight,
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: dark ? borderDark : borderLight,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: brandGold,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
    );
  }

  static BoxDecoration cardDecoration(
    BuildContext context, {
    double radius = 18,
    bool hasBorder = true,
    bool hasShadow = true,
    Color? customColor,
  }) {
    final dark = isDark(context);
    return BoxDecoration(
      color: customColor ?? (dark ? surfaceDark : surfaceLight),
      borderRadius: BorderRadius.circular(radius),
      border: hasBorder
          ? Border.all(
              color: dark ? borderDark : borderLight,
              width: 1,
            )
          : null,
      boxShadow: hasShadow
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.25 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ]
          : null,
    );
  }

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: bgLight,
    colorScheme: const ColorScheme.light(
      primary: primaryGreen,
      secondary: brandGold,
      tertiary: brandGoldDark,
      surface: surfaceLight,
      onSurface: textPrimaryLight,
      onPrimary: Colors.white,
    ),
    cardTheme: CardThemeData(
      color: surfaceLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: borderLight, width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bgLight,
      elevation: 0,
      iconTheme: IconThemeData(color: primaryGreen),
      titleTextStyle: TextStyle(
        color: textPrimaryLight,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: brandGold,
        foregroundColor: const Color(0xFF1B4332), // Dark forest text on gold
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFD8F3DC),
      labelStyle: const TextStyle(color: primaryGreen, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: const BorderSide(color: brandGold, width: 0.8),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgDark,
    colorScheme: const ColorScheme.dark(
      primary: leafGreen,
      secondary: brandGold,
      tertiary: brandGoldLight,
      surface: surfaceDark,
      onSurface: textPrimaryDark,
      onPrimary: Color(0xFF0B130E),
    ),
    cardTheme: CardThemeData(
      color: surfaceDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: borderDark, width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bgDark,
      elevation: 0,
      iconTheme: IconThemeData(color: brandGold),
      titleTextStyle: TextStyle(
        color: textPrimaryDark,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: brandGold,
        foregroundColor: const Color(0xFF0B130E),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF1E3A29),
      labelStyle: const TextStyle(color: brandGoldLight, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: const BorderSide(color: brandGoldDark, width: 0.8),
    ),
  );
}