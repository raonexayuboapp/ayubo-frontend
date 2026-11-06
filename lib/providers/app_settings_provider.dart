import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/money.dart';

// Theme Mode Notifier (Light / Dark / System)
class ThemeNotifier extends StateNotifier<ThemeMode> {
  static const _storageKey = 'app_theme_mode';
  static const _storage = FlutterSecureStorage();

  ThemeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final saved = await _storage.read(key: _storageKey);
      if (saved == 'dark') {
        state = ThemeMode.dark;
      } else if (saved == 'light') {
        state = ThemeMode.light;
      }
    } catch (_) {}
  }

  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = newMode;
    try {
      await _storage.write(key: _storageKey, value: newMode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    try {
      final val = mode == ThemeMode.dark ? 'dark' : mode == ThemeMode.light ? 'light' : 'system';
      await _storage.write(key: _storageKey, value: val);
    } catch (_) {}
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

// Language / Locale Notifier (English / German)
class LocaleNotifier extends StateNotifier<Locale> {
  static const _storageKey = 'app_language_code';
  static const _storage = FlutterSecureStorage();

  LocaleNotifier() : super(const Locale('en')) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final saved = await _storage.read(key: _storageKey);
      if (saved == 'de' || saved == 'en') {
        final code = saved!;
        currentAppLocale = code;
        state = Locale(code);
      }
    } catch (_) {}
  }

  Future<void> setLocale(String languageCode) async {
    if (languageCode != 'en' && languageCode != 'de') return;
    currentAppLocale = languageCode;
    state = Locale(languageCode);
    try {
      await _storage.write(key: _storageKey, value: languageCode);
    } catch (_) {}
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});
