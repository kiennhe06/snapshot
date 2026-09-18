import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import 'press_scale.dart';

enum AppButtonVariant { primary, secondary, ghost }

/// Custom button (replaces Filled/Outlined/TextButton). Primary is a rose block
/// with a brand glow; secondary is an outlined surface; ghost is text-only.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    final isPrimary = variant == AppButtonVariant.primary;
    final isSecondary = variant == AppButtonVariant.secondary;

    final fg = isPrimary
        ? AppColors.textPrimary
        : (isSecondary ? AppColors.textPrimary : AppColors.primary);

    final content = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.textPrimary,
            ),
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppIconSize.md, color: fg),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: AppType.subhead,
                  fontWeight: AppType.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          );

    return Opacity(
      opacity: disabled && !isLoading ? 0.5 : 1,
      child: PressScale(
        onTap: disabled ? null : onPressed,
        child: Container(
          height: 52,
          width: fullWidth ? double.infinity : null,
          alignment: Alignment.center,
          padding: fullWidth
              ? null
              : const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: isPrimary
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.primaryBright, AppColors.primary],
                  )
                : null,
            color: isSecondary ? AppColors.layer2 : null,
            borderRadius: AppRadius.brMd,
            border: isSecondary
                ? Border.all(color: AppColors.borderStrong)
                : null,
            boxShadow: isPrimary && !disabled ? AppShadows.brandGlow : null,
          ),
          child: content,
        ),
      ),
    );
  }
}
