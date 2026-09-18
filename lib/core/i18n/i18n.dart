import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported languages (Vietnamese + English only).
enum AppLang { vi, en }

/// Global current language, kept in sync by [App] from [localeProvider]. Widgets
/// call the top-level [tr] with both strings; because MaterialApp is rebuilt
/// with a language-keyed ValueKey, the whole tree re-reads this on change.
AppLang currentLang = AppLang.vi;

/// Pick the string for the active language: `tr('Tiếng Việt', 'English')`.
String tr(String vi, String en) => currentLang == AppLang.vi ? vi : en;

Locale localeOf(AppLang lang) =>
    lang == AppLang.vi ? const Locale('vi') : const Locale('en');

/// Persisted language controller.
final localeProvider = NotifierProvider<LocaleController, AppLang>(
  LocaleController.new,
);

class LocaleController extends Notifier<AppLang> {
  static const _key = 'app_lang_v1';

  @override
  AppLang build() {
    _load();
    return currentLang;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved == 'en') {
        currentLang = AppLang.en;
        state = AppLang.en;
      }
    } catch (_) {
      // Keep default vi.
    }
  }

  Future<void> set(AppLang lang) async {
    currentLang = lang;
    state = lang;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, lang == AppLang.en ? 'en' : 'vi');
    } catch (_) {}
  }

  void toggle() => set(state == AppLang.vi ? AppLang.en : AppLang.vi);
}
