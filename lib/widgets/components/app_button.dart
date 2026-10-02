import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import 'press_scale.dart';

enum AppButtonVariant { primary, secondary, ghost }

/// Custom pill button ("Moment" style): fully rounded, soft pink gradient fill
/// with a gentle glow (primary); soft white pill with pink border/text
/// (secondary); text-only (ghost).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    final isPrimary = variant == AppButtonVariant.primary;
    final isSecondary = variant == AppButtonVariant.secondary;

    final fg = isPrimary ? Colors.white : AppColors.primary;

    final content = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppIconSize.md, color: fg),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(label, style: AppText.button.copyWith(color: fg)),
            ],
          );

    // LEGO: flat brick fill + black outline + hard block shadow (no gradient/
    // glow). Neon: gradient + bevel + glow. Other skins: the original look.
    final lego = isLegoDisplay;
    final Border? brder = lego
        ? ((isPrimary || isSecondary) ? AppDepth.brickBorder() : null)
        : (isSecondary
              ? Border.all(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  width: 1.5,
                )
              : (isPrimary ? AppDepth.controlEdge : null));
    final List<BoxShadow>? shdw = disabled
        ? null
        : (lego
              ? ((isPrimary || isSecondary) ? AppDepth.brickShadow() : null)
              : (isPrimary ? AppDepth.controlLift : null));
    return Opacity(
      opacity: disabled && !isLoading ? 0.55 : 1,
      child: PressScale(
        onTap: disabled ? null : onPressed,
        child: Container(
          height: height,
          width: fullWidth ? double.infinity : null,
          alignment: Alignment.center,
          padding: fullWidth
              ? null
              : const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          // Glossy top sheen on the neon skin (no-op elsewhere); only on filled
          // variants so the ghost/secondary pills stay flat.
          foregroundDecoration: isPrimary
              ? AppDepth.sheen(BorderRadius.circular(AppRadius.pill))
              : null,
          decoration: BoxDecoration(
            gradient: isPrimary && !lego
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryBright, AppColors.primary],
                  )
                : null,
            color: isSecondary
                ? AppColors.layer2
                : (isPrimary && lego ? AppColors.primary : null),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: brder,
            boxShadow: shdw,
          ),
          child: content,
        ),
      ),
    );
  }
}
