import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized cyberpunk palette.
class CyberpunkColors {
  // Background
  static const background = Color(0xFF050508);

  // Surfaces
  static const surface = Color(0xFF0F0F14);
  static const card = Color(0xFF121218);

  // Neons
  static const primary = Color(0xFFB6FF2B); // neon lime/green
  static const competitive = Color(0xFFFF2D55); // neon pink/red
  static const secondary = Color(0xFFB100FF); // purple/magenta

  // Text
  static const textPrimary = Color(0xFFEDEDED);
  static const textSecondary = Color(0xFF9AA0A6);

  // Borders
  static const border = Color(0xFF232330);

  static Color alpha(Color color, double opacity) =>
      color.withValues(alpha: opacity.clamp(0, 1));
}

class ThemeNotifier extends ChangeNotifier {
  static const _key = 'isDarkTheme';
  ThemeMode _mode = ThemeMode.dark;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  ThemeNotifier() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_key) ?? true;
    _mode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> setDark(bool isDark) async {
    _mode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, isDark);
  }

  Future<void> toggle() async => setDark(!isDark);
}

ThemeData buildDarkTheme() {
  const cs = ColorScheme.dark(
    primary: CyberpunkColors.primary,
    secondary: CyberpunkColors.secondary,
    surface: CyberpunkColors.surface,
    error: CyberpunkColors.competitive,
  );

  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: cs,
    scaffoldBackgroundColor: CyberpunkColors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: CyberpunkColors.background,
      elevation: 0,
      foregroundColor: CyberpunkColors.textPrimary,
      titleTextStyle: GoogleFonts.rajdhani(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: CyberpunkColors.primary,
      ),
      centerTitle: true,
    ),
    cardColor: CyberpunkColors.card,
    dividerColor: CyberpunkColors.border,
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? CyberpunkColors.primary
            : Colors.grey,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? CyberpunkColors.primary.withValues(alpha: 0.35)
            : CyberpunkColors.border.withValues(alpha: 0.9),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CyberpunkColors.card,
      hintStyle: const TextStyle(color: CyberpunkColors.textSecondary, height: 1.2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CyberpunkColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CyberpunkColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: CyberpunkColors.primary.withValues(alpha: 0.9), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: CyberpunkColors.competitive.withValues(alpha: 0.9), width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: CyberpunkColors.competitive.withValues(alpha: 0.9), width: 2),
      ),
    ),
    textTheme: GoogleFonts.rajdhaniTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: CyberpunkColors.textPrimary,
      displayColor: CyberpunkColors.textPrimary,
    ),
    useMaterial3: true,
  );
}

ThemeData buildLightTheme() {
  // A minimal light variant (app defaults to dark cyberpunk).
  return ThemeData(
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: CyberpunkColors.primary,
      secondary: CyberpunkColors.secondary,
      surface: Colors.white,
      error: CyberpunkColors.competitive,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: CyberpunkColors.textPrimary,
      titleTextStyle: GoogleFonts.rajdhani(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: CyberpunkColors.primary,
      ),
      centerTitle: true,
    ),
    cardColor: Colors.white,
    dividerColor: Colors.black12,
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? CyberpunkColors.primary
            : Colors.grey,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? CyberpunkColors.primary.withValues(alpha: 0.35)
            : Colors.black12,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: Color(0xFF6B7280), height: 1.2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: CyberpunkColors.primary.withValues(alpha: 0.9), width: 2),
      ),
    ),
    textTheme: GoogleFonts.rajdhaniTextTheme(ThemeData.light().textTheme).apply(
      bodyColor: CyberpunkColors.textPrimary,
      displayColor: CyberpunkColors.textPrimary,
    ),
    useMaterial3: true,
  );
}
