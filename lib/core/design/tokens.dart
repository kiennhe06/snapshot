import 'package:flutter/material.dart';

/// Design tokens from the UI/UX Pro Max design system ("Snapshot" — Vibrant &
/// Block-based, social media). Single source of truth for the palette; the app
/// consumes these only through [ThemeData]/`Theme.of(context)`, never raw hex.
class AppPalette {
  const AppPalette._();

  // Brand
  static const Color primary = Color(0xFFE11D48); // vibrant rose
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color secondary = Color(0xFFFB7185);
  static const Color onSecondary = Color(0xFF0F172A);
  static const Color accent = Color(0xFF2563EB); // engagement blue
  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color destructive = Color(0xFFDC2626);
  static const Color onDestructive = Color(0xFFFFFFFF);

  // Light surfaces (kept near-neutral so photos stay the hero)
  static const Color lightBackground = Color(0xFFFFFBFC); // faint rose white
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightForeground = Color(0xFF1B1420);
  static const Color lightMuted = Color(0xFFF0ECF2);
  static const Color lightMutedForeground = Color(0xFF5B5563);
  static const Color lightBorder = Color(0xFFECE3E7);

  // Dark surfaces
  static const Color darkBackground = Color(0xFF120A0E);
  static const Color darkSurface = Color(0xFF1C141A);
  static const Color darkSurfaceHigh = Color(0xFF261C23);
  static const Color darkForeground = Color(0xFFF6EEF1);
  static const Color darkMutedForeground = Color(0xFFB8AEB5);
  static const Color darkBorder = Color(0xFF3A2E36);
  static const Color darkPrimary = Color(
    0xFFFB7185,
  ); // lighter rose for contrast
  static const Color darkAccent = Color(0xFF60A5FA);
}

/// 4 / 8 dp spacing rhythm.
class AppSpacing {
  const AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Corner radii.
class AppRadius {
  const AppRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

/// Motion tokens (200–300ms per design system).
class AppDuration {
  const AppDuration._();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 300);
}
