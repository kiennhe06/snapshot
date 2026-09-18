import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/design/tokens.dart';

/// Builds the app themes from the design-system tokens ([AppPalette]).
/// Everything is token-driven so light and dark stay in sync and screens never
/// hardcode colors.

/// Playfair Display wordmark used for the "Snapshot" brand only.
TextStyle brandWordmark(BuildContext context, {double size = 24}) {
  return GoogleFonts.playfairDisplay(
    fontSize: size,
    fontWeight: FontWeight.w700,
    fontStyle: FontStyle.italic,
    color: Theme.of(context).colorScheme.primary,
  );
}

ThemeData buildLightTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.primary,
    onPrimary: AppPalette.onPrimary,
    secondary: AppPalette.accent,
    onSecondary: AppPalette.onAccent,
    tertiary: AppPalette.secondary,
    onTertiary: AppPalette.onSecondary,
    error: AppPalette.destructive,
    onError: AppPalette.onDestructive,
    surface: AppPalette.lightSurface,
    onSurface: AppPalette.lightForeground,
    surfaceContainerHighest: AppPalette.lightMuted,
    onSurfaceVariant: AppPalette.lightMutedForeground,
    outline: AppPalette.lightMutedForeground,
    outlineVariant: AppPalette.lightBorder,
  );
  return _base(scheme, AppPalette.lightBackground);
}

ThemeData buildDarkTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalette.darkPrimary,
    onPrimary: Color(0xFF3B0A16),
    secondary: AppPalette.darkAccent,
    onSecondary: Color(0xFF0A1A33),
    tertiary: AppPalette.secondary,
    onTertiary: AppPalette.onSecondary,
    error: Color(0xFFF87171),
    onError: Color(0xFF3B0A0A),
    surface: AppPalette.darkSurface,
    onSurface: AppPalette.darkForeground,
    surfaceContainerHighest: AppPalette.darkSurfaceHigh,
    onSurfaceVariant: AppPalette.darkMutedForeground,
    outline: AppPalette.darkMutedForeground,
    outlineVariant: AppPalette.darkBorder,
  );
  return _base(scheme, AppPalette.darkBackground);
}

ThemeData _base(ColorScheme scheme, Color scaffoldBg) {
  final textTheme = GoogleFonts.interTextTheme(
    ThemeData(brightness: scheme.brightness).textTheme,
  );

  OutlineInputBorder border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: BorderSide(color: c),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffoldBg,
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,

    appBarTheme: AppBarTheme(
      backgroundColor: scaffoldBg,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        // Min height only for touch target; width stays content/parent driven
        // (Size.fromHeight would force infinite width and crash inside Rows).
        minimumSize: const Size(0, 50),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: border(scheme.outlineVariant),
      enabledBorder: border(scheme.outlineVariant),
      focusedBorder: border(scheme.primary),
      errorBorder: border(scheme.error),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),

    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    ),

    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 0.5,
      space: 0.5,
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: scheme.primary,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  );
}
