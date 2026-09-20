import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00E5FF),
      secondary: Color(0xFFFFC107),
      surface: Color(0xFF141414),
      error: Color(0xFFE53935),
    ),
    scaffoldBackgroundColor: const Color(0xFF0A0A0A),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF0D0D0D),
      elevation: 0,
      foregroundColor: Colors.white,
      titleTextStyle: GoogleFonts.rajdhani(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF00E5FF)),
    ),
    cardColor: const Color(0xFF141414),
    dividerColor: Colors.white10,
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? const Color(0xFF00E5FF) : Colors.grey),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? const Color(0xFF00E5FF).withValues(alpha: 0.4) : Colors.white12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      hintStyle: const TextStyle(color: Colors.white38),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    ),
    textTheme: GoogleFonts.rajdhaniTextTheme(ThemeData.dark().textTheme),
    useMaterial3: true,
  );
}

ThemeData buildLightTheme() {
  return ThemeData(
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF0097A7),
      secondary: Color(0xFFF57F17),
      surface: Color(0xFFF5F5F5),
      error: Color(0xFFD32F2F),
    ),
    scaffoldBackgroundColor: const Color(0xFFF0F4F8),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: const Color(0xFF0097A7),
      titleTextStyle: GoogleFonts.rajdhani(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF0097A7)),
    ),
    cardColor: Colors.white,
    dividerColor: Colors.black12,
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? const Color(0xFF0097A7) : Colors.grey),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? const Color(0xFF0097A7).withValues(alpha: 0.4) : Colors.black12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: Colors.black38),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black12)),
    ),
    textTheme: GoogleFonts.rajdhaniTextTheme(ThemeData.light().textTheme),
    useMaterial3: true,
  );
}
