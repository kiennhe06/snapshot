import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/design/tokens.dart';

/// Premium dark theme built from [AppColors] tokens. Custom components carry the
/// signature look; this ThemeData keeps any not-yet-migrated Material widgets
/// on-palette in the meantime.

/// Playfair Display italic wordmark for the "Snapshot" brand.
TextStyle brandWordmark(BuildContext context, {double size = 24}) {
  return GoogleFonts.playfairDisplay(
    fontSize: size,
    fontWeight: FontWeight.w700,
    fontStyle: FontStyle.italic,
    color: AppColors.primary,
  );
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: Color(0xFFFFFFFF),
    secondary: AppColors.accent,
    onSecondary: Color(0xFFFFFFFF),
    tertiary: AppColors.primaryBright,
    onTertiary: Color(0xFFFFFFFF),
    error: AppColors.danger,
    onError: Color(0xFFFFFFFF),
    surface: AppColors.layer2,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.layer3,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.textTertiary,
    outlineVariant: AppColors.borderSubtle,
  );

  final textTheme =
      GoogleFonts.interTextTheme(
        ThemeData(brightness: Brightness.light).textTheme,
      ).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.scaffold,
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.borderSubtle,
      thickness: 0.5,
      space: 0.5,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.layer5,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.layer5,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: const TextStyle(color: Color(0xFFFFFFFF)),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.textPrimary
            : AppColors.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.layer3,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),

    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorColor: AppColors.primary,
      dividerColor: Colors.transparent,
      labelStyle: TextStyle(fontWeight: AppType.bold),
    ),

    iconTheme: const IconThemeData(color: AppColors.textSecondary),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
    ),
  );
}
