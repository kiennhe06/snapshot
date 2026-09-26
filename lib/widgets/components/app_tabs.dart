import 'package:flutter/material.dart';

import '../../core/design/motion.dart';
import '../../core/design/tokens.dart';
import 'press_scale.dart';

/// Reusable pill segmented control (replaces Material TabBar). The active
/// segment gets a soft raised white pill.
class AppSegmentedTabs extends StatelessWidget {
  const AppSegmentedTabs({
    super.key,
    required this.index,
    required this.labels,
    required this.onChanged,
    this.margin = const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.xs,
      AppSpacing.md,
      AppSpacing.md,
    ),
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final n = labels.length;
    // Slide alignment: map the active index across the track's width.
    final alignX = n > 1 ? -1.0 + 2.0 * (index / (n - 1)) : 0.0;
    final motion = Motion.dur(context, AppMotion.base);
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.layer3,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Stack(
        children: [
          // One pill that glides to the active segment (instead of fading
          // per-cell), so the selection reads as a single moving object.
          Positioned.fill(
            child: AnimatedAlign(
              duration: motion,
              curve: AppMotion.inOut,
              alignment: Alignment(alignX, 0),
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.layer1,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: AppShadows.soft,
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: List.generate(n, (i) {
              final active = i == index;
              return Expanded(
                child: PressScale(
                  onTap: () {
                    Motion.selection();
                    onChanged(i);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: AnimatedDefaultTextStyle(
                      duration: motion,
                      curve: AppMotion.standard,
                      style: TextStyle(
                        color: active
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontSize: AppType.body,
                        fontWeight: active ? AppType.bold : AppType.medium,
                      ),
                      child: Text(labels[i], textAlign: TextAlign.center),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Icon-only pill tabs (e.g. profile grid / reels / tagged).
class AppIconTabs extends StatelessWidget {
  const AppIconTabs({
    super.key,
    required this.index,
    required this.icons,
    required this.onChanged,
  });

  final int index;
  final List<IconData> icons;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(icons.length, (i) {
        final active = i == index;
        return Expanded(
          child: PressScale(
            onTap: () => onChanged(i),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: active ? AppColors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Icon(
                icons[i],
                color: active ? AppColors.primary : AppColors.textTertiary,
                size: AppIconSize.lg,
              ),
            ),
          ),
        );
      }),
    );
  }
}
