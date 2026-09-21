import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';

/// Shared small section heading: UPPERCASE, secondary colour, optional leading
/// primary icon. One style for field-group labels across composers/settings.
class AppSectionLabel extends StatelessWidget {
  const AppSectionLabel(this.text, {super.key, this.icon, this.trailing});

  final String text;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
        ],
        Text(
          text.toUpperCase(),
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppType.label,
            fontWeight: AppType.bold,
            letterSpacing: 0.8,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}
