import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';

/// A filled count pill (unread messages, notifications). Caps at 99+.
class AppCountBadge extends StatelessWidget {
  const AppCountBadge(this.count, {super.key, this.color});

  final int count;

  /// Fill colour; defaults to the brand primary.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color ?? AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: AppText.caption.copyWith(
          color: AppColors.onPrimary,
          fontWeight: AppType.heavy,
        ),
      ),
    );
  }
}

/// A tinted label chip (kind/status tags like "Channel", "Group", "Live").
/// The tint is a translucent wash of [color] with matching text.
class AppTag extends StatelessWidget {
  const AppTag(this.label, {super.key, this.color});

  final String label;

  /// Accent used for both wash and text; defaults to [AppColors.accent].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: AppText.caption.copyWith(color: c, fontWeight: AppType.bold),
      ),
    );
  }
}
