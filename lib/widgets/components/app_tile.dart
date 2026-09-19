import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import 'press_scale.dart';

/// Custom list row (replaces Material ListTile). Optional leading/trailing,
/// title + subtitle, with press feedback.
class AppTile extends StatelessWidget {
  const AppTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      color: Colors.transparent,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: dense ? AppSpacing.sm : AppSpacing.md,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titleColor ?? AppColors.textPrimary,
                    fontSize: AppType.subhead,
                    fontWeight: AppType.medium,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppType.label,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return PressScale(onTap: onTap, child: row);
  }
}

/// Circular avatar with a consistent placeholder.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.imageProvider,
    this.radius = 22,
    this.icon = Icons.person_rounded,
  });
  final ImageProvider? imageProvider;
  final double radius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.layer3,
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Icon(icon, size: radius, color: AppColors.textSecondary)
          : null,
    );
  }
}
