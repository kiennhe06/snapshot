import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tokens.dart';

/// The skins the user can pick in Settings → Display.
enum DisplaySkin { light, dark, neon }

/// The palette backing each skin. Kept here (not in tokens.dart) so the enum and
/// its palettes stay together; tokens.dart only exposes [applyPalette].
AppPalette paletteFor(DisplaySkin skin) => switch (skin) {
  DisplaySkin.light => kLightPalette,
  DisplaySkin.dark => kDarkPalette,
  DisplaySkin.neon => kNeonPalette,
};

/// Human label for a skin (VI, EN).
({String vi, String en}) skinLabel(DisplaySkin skin) => switch (skin) {
  DisplaySkin.light => (vi: 'Sáng · Moment', en: 'Light · Moment'),
  DisplaySkin.dark => (vi: 'Tối · Nova', en: 'Dark · Nova'),
  DisplaySkin.neon => (vi: '3D Game · Neon', en: '3D Game · Neon'),
};

/// Persisted display-skin controller. [App] watches this, applies the palette,
/// and re-keys the widget tree so every token re-reads.
final displayThemeProvider =
    NotifierProvider<DisplayThemeController, DisplaySkin>(
      DisplayThemeController.new,
    );

class DisplayThemeController extends Notifier<DisplaySkin> {
  static const _key = 'display_skin_v1';

  @override
  DisplaySkin build() {
    _load();
    applyPalette(paletteFor(DisplaySkin.light));
    return DisplaySkin.light;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved == null) return;
      // Stored as the enum name ('light' / 'dark' / 'neon'); older builds stored
      // 'dark' / 'light' too, which still match by name.
      final skin = DisplaySkin.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => DisplaySkin.light,
      );
      if (skin != DisplaySkin.light) {
        applyPalette(paletteFor(skin));
        state = skin;
      }
    } catch (_) {
      // Keep default light.
    }
  }

  Future<void> set(DisplaySkin skin) async {
    applyPalette(paletteFor(skin));
    state = skin;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, skin.name);
    } catch (_) {}
  }
}
