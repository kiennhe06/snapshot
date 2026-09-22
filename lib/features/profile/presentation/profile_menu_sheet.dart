import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../widgets/components/components.dart';
import '../../auth/providers/auth_providers.dart';
import '../../interactions/providers/interaction_providers.dart';
import '../../post/providers/post_providers.dart';
import '../providers/profile_providers.dart';

/// Profile hub (Concept B, level 1): the frequently-used "my activity" shortcuts
/// as grouped cards, one door into full Settings, and Log out — instead of a
/// flat 10-row menu. [parentContext] is used for routing after the sheet closes.
Future<void> showProfileMenu(BuildContext context) {
  return showAppSheet<void>(
    context,
    builder: (_) => _ProfileMenu(parentContext: context),
  );
}

class _ProfileMenu extends ConsumerWidget {
  const _ProfileMenu({required this.parentContext});
  final BuildContext parentContext;

  void _go(BuildContext sheetContext, String route) {
    Navigator.pop(sheetContext);
    parentContext.push(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    final savedCount = ref.watch(savedPostsProvider(null)).valueOrNull?.length;
    final draftCount = ref.watch(draftsProvider).valueOrNull?.length;
    final archiveCount = uid == null
        ? null
        : ref
              .watch(authoredPostsProvider(uid))
              .valueOrNull
              ?.where((p) => p.isArchived)
              .length;

    return AppSheetSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // My activity + settings — one tidy list. Counts show only when > 0.
          _MenuRow(
            icon: Icons.bookmark_rounded,
            label: tr('Đã lưu', 'Saved'),
            count: savedCount,
            onTap: () => _go(context, Routes.saved),
          ),
          _MenuRow(
            icon: Icons.archive_rounded,
            label: tr('Lưu trữ', 'Archive'),
            count: archiveCount,
            onTap: () => _go(context, Routes.archive),
          ),
          _MenuRow(
            icon: Icons.edit_note_rounded,
            label: tr('Bản nháp', 'Drafts'),
            count: draftCount,
            onTap: () => _go(context, Routes.drafts),
          ),
          Divider(height: 1, color: AppColors.borderSubtle),
          _MenuRow(
            icon: Icons.settings_outlined,
            label: tr('Cài đặt & quyền riêng tư', 'Settings & privacy'),
            onTap: () => _go(context, Routes.settings),
          ),
          Divider(height: 1, color: AppColors.borderSubtle),
          _MenuRow(
            icon: Icons.logout_rounded,
            label: tr('Đăng xuất', 'Log out'),
            destructive: true,
            onTap: () async {
              Navigator.pop(context);
              await ref.read(authServiceProvider).signOut();
            },
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? count;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.danger : AppColors.textPrimary;
    return PressScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: AppIconSize.md,
              color: destructive ? AppColors.danger : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: AppType.subhead,
                  fontWeight: AppType.medium,
                ),
              ),
            ),
            // Show a count only when there is something worth noting.
            if (count != null && count! > 0)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppType.subhead,
                    fontWeight: AppType.bold,
                  ),
                ),
              ),
            if (!destructive)
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}
