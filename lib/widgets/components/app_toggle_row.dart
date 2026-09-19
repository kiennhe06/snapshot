import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import 'app_switch.dart';

/// One settings/preferences row: a label (+ optional subtitle) with a trailing
/// [AppSwitch]. The single toggle pattern across the app — never build a bare
/// Material `Switch` in a screen. Tapping the whole row flips the switch.
class AppToggleRow extends StatelessWidget {
  const AppToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: AppIconSize.md, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppType.subhead,
                      fontWeight: AppType.medium,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: AppType.label,
                          height: 1.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            AppSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
