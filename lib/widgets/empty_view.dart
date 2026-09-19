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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
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
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppType.subhead,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
