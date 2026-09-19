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
                child:
                    titleWidget ??
                    Text(
                      title ?? '',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: AppType.title,
                        fontWeight: AppType.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
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
    final button = PressScale(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? AppColors.primary.withValues(alpha: 0.16)
              : AppColors.layer2.withValues(alpha: 0.0),
        ),
        child: Icon(
          icon,
          size: size,
          color:
              color ?? (active ? AppColors.primary : AppColors.textSecondary),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
