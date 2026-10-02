import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import 'press_scale.dart';

/// Custom top bar (replaces Material AppBar). Title expands so actions stay
/// pinned to the right edge; an optional [bottom] hosts a custom tab strip.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    this.title,
    this.titleWidget,
    this.showBack = false,
    this.onBack,
    this.actions = const [],
    this.bottom,
  });

  final String? title;
  final Widget? titleWidget;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              if (showBack)
                AppIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: onBack ?? () => Navigator.of(context).maybePop(),
                ),
              if (showBack) const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: titleWidget ?? Text(title ?? '', style: AppText.h1),
              ),
              ...actions,
            ],
          ),
        ),
        ?bottom,
      ],
    );
  }
}

/// Circular icon button with a subtle raised surface and press feedback.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color,
    this.size = AppIconSize.md,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? color;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    // On the Neon 3D skin every icon sits in a raised rounded-square chip
    // (bevel rim + subtle fill + glow), like a game HUD key. Other skins keep
    // the flat transparent circle.
    final neon = isNeonDisplay;
    final iconColor =
        color ?? (active ? AppColors.primaryBright : AppColors.textSecondary);
    final button = PressScale(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        foregroundDecoration: neon
            ? AppDepth.sheen(BorderRadius.circular(AppRadius.sm))
            : null,
        decoration: neon
            ? BoxDecoration(
                gradient: AppGradients.elevated,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: active
                      ? AppColors.primary.withValues(alpha: 0.75)
                      : AppColors.borderStrong,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (active ? AppColors.primary : Colors.black)
                        .withValues(alpha: active ? 0.35 : 0.4),
                    blurRadius: active ? 16 : 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              )
            : BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? AppColors.primary.withValues(alpha: 0.16)
                    : AppColors.layer2.withValues(alpha: 0.0),
              ),
        child: Icon(
          icon,
          size: size,
          color: iconColor,
          shadows: neon && active ? AppDepth.iconGlow : null,
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
