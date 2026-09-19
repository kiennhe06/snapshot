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
          // My activity — grouped content cards
          Row(
              children: [
                Expanded(
                  child: _ActivityCard(
                    icon: Icons.bookmark_rounded,
                    label: tr('Đã lưu', 'Saved'),
                    count: savedCount,
                    onTap: () => _go(context, Routes.saved),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _ActivityCard(
                    icon: Icons.archive_rounded,
                    label: tr('Lưu trữ', 'Archive'),
                    count: archiveCount,
                    onTap: () => _go(context, Routes.archive),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _ActivityCard(
                    icon: Icons.edit_note_rounded,
                    label: tr('Bản nháp', 'Drafts'),
                    count: draftCount,
                    onTap: () => _go(context, Routes.drafts),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // One door into everything else
            _MenuRow(
              icon: Icons.settings_outlined,
              label: tr('Cài đặt & quyền riêng tư', 'Settings & privacy'),
              onTap: () => _go(context, Routes.settings),
            ),
            const Divider(height: 1, color: AppColors.borderSubtle),
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

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.sm,
      ),
      child: Column(
        children: [
          Icon(icon, size: AppIconSize.lg, color: AppColors.primary),
          const SizedBox(height: AppSpacing.sm),
          Text(
            count == null ? '—' : '$count',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppType.headline,
              fontWeight: AppType.heavy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppType.label,
              fontWeight: AppType.medium,
            ),
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
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
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
            if (!destructive)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}
