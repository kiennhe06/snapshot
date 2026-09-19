import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tokens.dart';

/// The two skins the user can pick in Settings → Display.
enum DisplaySkin { light, dark }

/// Persisted display-skin controller. [App] watches this, applies the palette,
/// and re-keys the widget tree so every token re-reads.
final displayThemeProvider = NotifierProvider<DisplayThemeController, DisplaySkin>(
  DisplayThemeController.new,
);

class DisplayThemeController extends Notifier<DisplaySkin> {
  static const _key = 'display_skin_v1';

  @override
  DisplaySkin build() {
    _load();
    applyDisplayTheme(false);
    return DisplaySkin.light;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_key) == 'dark') {
        applyDisplayTheme(true);
        state = DisplaySkin.dark;
      }
    } catch (_) {
      // Keep default light.
    }
  }

  Future<void> set(DisplaySkin skin) async {
    applyDisplayTheme(skin == DisplaySkin.dark);
    state = skin;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, skin == DisplaySkin.dark ? 'dark' : 'light');
    } catch (_) {}
  }

  void toggle() =>
      set(state == DisplaySkin.dark ? DisplaySkin.light : DisplaySkin.dark);
}
