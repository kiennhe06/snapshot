import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import 'press_scale.dart';

class AppNavItem {
  const AppNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Custom bottom navigation (replaces Material NavigationBar). A raised layer-1
/// bar with a rounded rose indicator behind the active item.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.section,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        boxShadow: AppShadows.overlay,
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: bottomInset + AppSpacing.sm,
        left: AppSpacing.sm,
        right: AppSpacing.sm,
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final active = i == currentIndex;
          final item = items[i];
          return Expanded(
            child: PressScale(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: AppMotion.base,
                curve: AppMotion.standard,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: AppRadius.brMd,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      active ? item.activeIcon : item.icon,
                      size: AppIconSize.lg,
                      color: active
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: AppType.caption,
                        fontWeight: active ? AppType.bold : AppType.medium,
                        color: active
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
