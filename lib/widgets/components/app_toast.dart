import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';

/// Toast intent — drives the leading icon and accent.
enum AppToastType { neutral, success, error }

/// The single feedback toast for the whole app. Use instead of a raw
/// `ScaffoldMessenger.showSnackBar(SnackBar(...))` so every transient message
/// shares the Moment surface, shape, motion and semantics.
void showAppToast(
  BuildContext context,
  String message, {
  AppToastType type = AppToastType.neutral,
}) {
  final (icon, accent) = switch (type) {
    AppToastType.success => (Icons.check_circle_rounded, AppColors.success),
    AppToastType.error => (Icons.error_rounded, AppColors.danger),
    AppToastType.neutral => (Icons.info_rounded, AppColors.primary),
  };

  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.all(AppSpacing.md),
        content: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.layer1,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: AppShadows.medium,
          ),
          child: Row(
            children: [
              Icon(icon, size: AppIconSize.md, color: accent),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppType.subhead,
                    fontWeight: AppType.medium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
}
