import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import 'press_scale.dart';

/// Shared horizontal filter chip. Selected chips paint the brand gradient;
/// unselected chips are a subtle layer with a hairline border.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neon = isNeonDisplay;
    return PressScale(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        foregroundDecoration: neon && selected
            ? AppDepth.sheen(BorderRadius.circular(AppRadius.pill))
            : null,
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [AppColors.primaryBright, AppColors.primary],
                )
              : (neon ? AppGradients.elevated : null),
          color: selected ? null : (neon ? null : AppColors.layer1),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected
                ? (neon
                      ? AppColors.primaryBright.withValues(alpha: 0.6)
                      : Colors.transparent)
                : (neon ? AppColors.borderStrong : AppColors.borderSubtle),
          ),
          boxShadow: neon && selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: AppType.label,
            fontWeight: AppType.bold,
          ),
        ),
      ),
    );
  }
}

/// Circular brand-gradient icon action (message send / comment submit).
class AppGradientIconButton extends StatelessWidget {
  const AppGradientIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryBright, AppColors.primary],
          ),
          boxShadow: AppShadows.brandGlow,
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }
}
