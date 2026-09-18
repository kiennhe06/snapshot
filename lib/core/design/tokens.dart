import 'package:flutter/material.dart';

/// Design tokens — "Moment" light aesthetic: soft, airy, pink-tinted, content
/// first. Single source of truth. Custom components + screens reference ONLY
/// these (never raw hex / literal sizes).

/// Surfaces are light; "layer" naming kept so components need no changes.
abstract class AppColors {
  // Surfaces (light, faint pink)
  static const Color scaffold = Color(0xFFFBF4F7); // page background
  static const Color layer1 = Color(0xFFFFFFFF); // nav / section / filter
  static const Color layer2 = Color(0xFFFFFFFF); // card
  static const Color layer3 = Color(0xFFFDECF2); // active chip / raised
  static const Color layer5 = Color(0xFFFFFFFF); // modal / sheet / menu

  // Brand (soft rose-pink)
  static const Color primary = Color(0xFFEC4A73);
  static const Color primaryBright = Color(0xFFFF7BA3); // hover / gradient top
  static const Color primaryDeep = Color(0xFFC42A54); // pressed
  static const Color accent = Color(0xFF8B5CF6); // soft violet, sparing

  // Text (on light)
  static const Color textPrimary = Color(0xFF201A22); // near-black, 15:1
  static const Color textSecondary = Color(0xFF6E5F69); // ~5:1
  static const Color textTertiary = Color(0xFFA99BA4); // decorative labels

  // Semantic
  static const Color success = Color(0xFF16A34A);
  static const Color liveDot = Color(0xFFEC4A73);
  static const Color warn = Color(0xFFD97706);
  static const Color danger = Color(0xFFE11D48);

  // Borders (soft pink-gray, opaque)
  static const Color borderSubtle = Color(0xFFF1E4EB);
  static const Color borderStrong = Color(0xFFE7D2DD);
}

/// 4-based spacing rhythm (airy — Moment uses generous spacing).
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

/// Soft, light, faintly pink shadows (not the heavy dark ones).
abstract class AppShadows {
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x14C4335C),
      blurRadius: 24,
      offset: Offset(0, 10),
      spreadRadius: -10,
    ),
    BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x1FC4335C),
      blurRadius: 40,
      offset: Offset(0, 18),
      spreadRadius: -12,
    ),
    BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> overlay = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 44,
      offset: Offset(0, -6),
      spreadRadius: 0,
    ),
  ];
  static const List<BoxShadow> brandGlow = [
    BoxShadow(color: Color(0x4DEC4A73), blurRadius: 22, offset: Offset(0, 10)),
  ];
}

/// Subtle light surface gradients (white → barely pink).
abstract class AppGradients {
  static const LinearGradient card = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFFFF8FB)],
  );
  static const LinearGradient elevated = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFFDECF2)],
  );
  static const LinearGradient section = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFFFF7FA)],
  );
}

/// Soft pink glow from the top behind every route.
abstract class AppBackground {
  static const RadialGradient glow = RadialGradient(
    center: Alignment(0, -0.85),
    radius: 1.2,
    colors: [Color(0xFFFCE0EC), Color(0xFFFBF4F7)],
    stops: [0, 0.6],
  );
}

abstract class AppDepth {
  static const Color topHighlight = Color(0x99FFFFFF);
}
