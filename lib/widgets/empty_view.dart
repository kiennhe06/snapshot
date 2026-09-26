import 'package:flutter/material.dart';

import '../core/design/tokens.dart';

/// Custom empty state drawn entirely in Flutter (no image asset): a soft glow
/// halo + raised circular chip + accent icon.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.accent,
  });

  final String message;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final accent = this.accent ?? AppColors.primary;
    // Center when there's room, scroll when the slot is short (avoids the
    // "bottom overflowed" error inside tight profile tab areas).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: 0.20),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.75],
                    ),
                  ),
                ),
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppGradients.card,
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.22),
                        blurRadius: 24,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 42, color: accent),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.h3.copyWith(
                color: AppColors.textSecondary,
                fontWeight: AppType.regular,
              ),
            ),
          ],
        ),
      ),
          ),
        ),
      ),
    );
  }
}
