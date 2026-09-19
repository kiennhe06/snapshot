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

/// Floating bottom navigation: a pill bar of icon + label tabs with a raised
/// gradient "create" button in the centre. Active tab reads in the brand
/// accent; the centre action stands proud of the bar.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.onCreate,
    this.createLabel = 'Đăng bài',
  });

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onCreate;
  final String createLabel;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final mid = items.length ~/ 2; // centre insertion point

    final slots = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (onCreate != null && i == mid) slots.add(_createButton());
      slots.add(Expanded(child: _tab(i)));
    }
    if (onCreate != null && mid == items.length) slots.add(_createButton());

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        bottomInset + AppSpacing.md,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.layer1,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: AppShadows.medium,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: slots,
        ),
      ),
    );
  }

  Widget _tab(int i) {
    final active = i == currentIndex;
    final item = items[i];
    final color = active ? AppColors.primary : AppColors.textTertiary;
    return PressScale(
      onTap: () => onTap(i),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? item.activeIcon : item.icon,
              size: AppIconSize.lg,
              color: color,
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: AppType.caption,
                fontWeight: active ? AppType.bold : AppType.medium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _createButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: PressScale(
        onTap: onCreate,
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryBright, AppColors.primary],
            ),
            boxShadow: AppShadows.brandGlow,
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}
