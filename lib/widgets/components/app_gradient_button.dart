import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import 'press_scale.dart';

/// The app-wide primary gradient CTA: a full-width brand-gradient pill with an
/// optional trailing arrow and a loading spinner. Used for prominent
/// "submit / share / continue" actions (auth, reel composer, …).
class AppGradientButton extends StatelessWidget {
  const AppGradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.showArrow = true,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final bool loading;
  final bool showArrow;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: loading ? null : onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accent,
              AppColors.primary,
              AppColors.primaryBright,
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: AppType.headline,
                      fontWeight: AppType.heavy,
                    ),
                  ),
                  if (showArrow) ...[
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  ],
                ],
              ),
      ),
    );
  }
}
