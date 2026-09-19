import 'package:flutter/material.dart';

/// Design tokens. Colours resolve through a swappable [AppPalette] so the app
/// can switch skins at runtime (Display setting) — every screen reads the same
/// tokens and re-colours together. Non-colour tokens (spacing, radius, type,
/// motion) stay compile-time const.

/// The full colour set for one skin.
class AppPalette {
  const AppPalette({
    required this.scaffold,
    required this.layer1,
    required this.layer2,
    required this.layer3,
    required this.layer5,
    required this.primary,
    required this.primaryBright,
    required this.primaryDeep,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.liveDot,
    required this.warn,
    required this.danger,
    required this.borderSubtle,
    required this.borderStrong,
    // gradients (top→bottom) + glow + shadow tints
    required this.cardTop,
    required this.cardBottom,
    required this.elevatedTop,
    required this.elevatedBottom,
    required this.sectionTop,
    required this.sectionBottom,
    required this.glowInner,
    required this.glowOuter,
    required this.shadowSoft,
    required this.shadowSoftLow,
    required this.shadowMedium,
    required this.shadowMediumLow,
    required this.shadowOverlay,
    required this.brandGlowColor,
    required this.topHighlight,
  });

  final Color scaffold, layer1, layer2, layer3, layer5;
  final Color primary, primaryBright, primaryDeep, accent;
  final Color textPrimary, textSecondary, textTertiary;
  final Color success, liveDot, warn, danger;
  final Color borderSubtle, borderStrong;
  final Color cardTop, cardBottom, elevatedTop, elevatedBottom;
  final Color sectionTop, sectionBottom;
  final Color glowInner, glowOuter;
  final Color shadowSoft, shadowSoftLow, shadowMedium, shadowMediumLow;
  final Color shadowOverlay, brandGlowColor, topHighlight;
}

/// "Moment" — the original soft, airy, pink-tinted light skin.
const AppPalette kLightPalette = AppPalette(
  scaffold: Color(0xFFFBF4F7),
  layer1: Color(0xFFFFFFFF),
  layer2: Color(0xFFFFFFFF),
  layer3: Color(0xFFFDECF2),
  layer5: Color(0xFFFFFFFF),
  primary: Color(0xFFEC4A73),
  primaryBright: Color(0xFFFF7BA3),
  primaryDeep: Color(0xFFC42A54),
  accent: Color(0xFF8B5CF6),
  textPrimary: Color(0xFF201A22),
  textSecondary: Color(0xFF6E5F69),
  textTertiary: Color(0xFFA99BA4),
  success: Color(0xFF16A34A),
  liveDot: Color(0xFFEC4A73),
  warn: Color(0xFFD97706),
  danger: Color(0xFFE11D48),
  borderSubtle: Color(0xFFF1E4EB),
  borderStrong: Color(0xFFE7D2DD),
  cardTop: Color(0xFFFFFFFF),
  cardBottom: Color(0xFFFFF8FB),
  elevatedTop: Color(0xFFFFFFFF),
  elevatedBottom: Color(0xFFFDECF2),
  sectionTop: Color(0xFFFFFFFF),
  sectionBottom: Color(0xFFFFF7FA),
  glowInner: Color(0xFFFCE0EC),
  glowOuter: Color(0xFFFBF4F7),
  shadowSoft: Color(0x14C4335C),
  shadowSoftLow: Color(0x0D000000),
  shadowMedium: Color(0x1FC4335C),
  shadowMediumLow: Color(0x12000000),
  shadowOverlay: Color(0x1F000000),
  brandGlowColor: Color(0x4DEC4A73),
  topHighlight: Color(0x99FFFFFF),
);

/// "Nova" — a creative dark skin (VibeFeed direction): near-black surfaces with
/// a violet→magenta accent. Photos stay the brightest thing on screen.
const AppPalette kDarkPalette = AppPalette(
  scaffold: Color(0xFF0C0C0F),
  layer1: Color(0xFF141418),
  layer2: Color(0xFF17171C),
  layer3: Color(0xFF242430),
  layer5: Color(0xFF1C1C22),
  primary: Color(0xFFB06BFF),
  primaryBright: Color(0xFFF45BB0),
  primaryDeep: Color(0xFF7A3FD0),
  accent: Color(0xFF4EA8FF),
  textPrimary: Color(0xFFF3F2F6),
  textSecondary: Color(0xFFA6A4B0),
  textTertiary: Color(0xFF6E6C78),
  success: Color(0xFF35D07F),
  liveDot: Color(0xFFF45BB0),
  warn: Color(0xFFF0A93A),
  danger: Color(0xFFFF5A78),
  borderSubtle: Color(0xFF262630),
  borderStrong: Color(0xFF34343F),
  cardTop: Color(0xFF17171C),
  cardBottom: Color(0xFF141419),
  elevatedTop: Color(0xFF1E1E26),
  elevatedBottom: Color(0xFF17171C),
  sectionTop: Color(0xFF161620),
  sectionBottom: Color(0xFF121218),
  glowInner: Color(0xFF241633),
  glowOuter: Color(0xFF0C0C0F),
  shadowSoft: Color(0x66000000),
  shadowSoftLow: Color(0x33000000),
  shadowMedium: Color(0x80000000),
  shadowMediumLow: Color(0x40000000),
  shadowOverlay: Color(0x99000000),
  brandGlowColor: Color(0x66B06BFF),
  topHighlight: Color(0x14FFFFFF),
);

/// The live palette. Swapped by [applyDisplayTheme]; the app re-keys its widget
/// tree on change so every token re-reads.
AppPalette _p = kLightPalette;

/// Whether the dark ("Nova") skin is active.
bool get isDarkDisplay => _p == kDarkPalette;

/// Switch the active skin. Call before rebuilding the app tree.
void applyDisplayTheme(bool dark) => _p = dark ? kDarkPalette : kLightPalette;

/// Surfaces + brand + text + semantic colours. All read from the live palette.
abstract class AppColors {
  static Color get scaffold => _p.scaffold;
  static Color get layer1 => _p.layer1;
  static Color get layer2 => _p.layer2;
  static Color get layer3 => _p.layer3;
  static Color get layer5 => _p.layer5;

  static Color get primary => _p.primary;
  static Color get primaryBright => _p.primaryBright;
  static Color get primaryDeep => _p.primaryDeep;
  static Color get accent => _p.accent;

  static Color get textPrimary => _p.textPrimary;
  static Color get textSecondary => _p.textSecondary;
  static Color get textTertiary => _p.textTertiary;

  static Color get success => _p.success;
  static Color get liveDot => _p.liveDot;
  static Color get warn => _p.warn;
  static Color get danger => _p.danger;

  static Color get borderSubtle => _p.borderSubtle;
  static Color get borderStrong => _p.borderStrong;
}

/// 4-based spacing rhythm (airy — generous spacing).
abstract class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Rounded, soft corners. card=xl, inner=lg, hero/sheet=xxl.
abstract class AppRadius {
  static const double xxs = 6;
  static const double xs = 10;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 28;
  static const double pill = 999;
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
}

abstract class AppIconSize {
  static const double xxs = 12;
  static const double xs = 14;
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 28;
}

abstract class AppType {
  static const double display = 30;
  static const double title = 20;
  static const double headline = 16;
  static const double subhead = 15;
  static const double body = 13;
  static const double label = 12;
  static const double small = 11;
  static const double caption = 10.5;

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight heavy = FontWeight.w800;
}

abstract class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
}

/// Depth shadows, tinted per skin.
abstract class AppShadows {
  static List<BoxShadow> get soft => [
    BoxShadow(
      color: _p.shadowSoft,
      blurRadius: 24,
      offset: const Offset(0, 10),
      spreadRadius: -10,
    ),
    BoxShadow(color: _p.shadowSoftLow, blurRadius: 6, offset: const Offset(0, 2)),
  ];
  static List<BoxShadow> get medium => [
    BoxShadow(
      color: _p.shadowMedium,
      blurRadius: 40,
      offset: const Offset(0, 18),
      spreadRadius: -12,
    ),
    BoxShadow(
      color: _p.shadowMediumLow,
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
  static List<BoxShadow> get overlay => [
    BoxShadow(
      color: _p.shadowOverlay,
      blurRadius: 44,
      offset: const Offset(0, -6),
    ),
  ];
  static List<BoxShadow> get brandGlow => [
    BoxShadow(
      color: _p.brandGlowColor,
      blurRadius: 22,
      offset: const Offset(0, 10),
    ),
  ];
}

/// Surface gradients, per skin.
abstract class AppGradients {
  static LinearGradient get card => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [_p.cardTop, _p.cardBottom],
  );
  static LinearGradient get elevated => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [_p.elevatedTop, _p.elevatedBottom],
  );
  static LinearGradient get section => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [_p.sectionTop, _p.sectionBottom],
  );
}

/// The soft glow behind every route, per skin.
abstract class AppBackground {
  static RadialGradient get glow => RadialGradient(
    center: const Alignment(0, -0.85),
    radius: 1.2,
    colors: [_p.glowInner, _p.glowOuter],
    stops: const [0, 0.6],
  );
}

abstract class AppDepth {
  static Color get topHighlight => _p.topHighlight;
}
