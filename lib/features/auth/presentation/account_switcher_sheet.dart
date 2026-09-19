import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/core/i18n/i18n.dart';
import 'package:snapshot/widgets/components/components.dart';
import '../../../models/stored_account.dart';
import '../providers/auth_providers.dart';

/// Shows the multi-account switcher as a modal bottom sheet.
Future<void> showAccountSwitcher(BuildContext context) {
  return showAppSheet<void>(
    context,
    builder: (_) => const _AccountSwitcherSheet(),
  );
}

class _AccountSwitcherSheet extends ConsumerWidget {
  const _AccountSwitcherSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;

    return AppSheetSurface(
      title: tr('Tài khoản', 'Accounts'),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            accountsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xxxl),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (_, _) => Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Text(
                  tr(
                    'Không tải được danh sách tài khoản.',
                    'Could not load the account list.',
                  ),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppType.subhead,
                  ),
                ),
              ),
              data: (accounts) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...accounts.map(
                    (a) => _AccountTile(
                      account: a,
                      isCurrent: a.uid == currentUid,
                      onSwitch: () => _switchTo(context, ref, a),
                      onRemove: () =>
                          ref.read(accountsProvider.notifier).remove(a.uid),
                    ),
                  ),
                  const Divider(
                    height: AppSpacing.md,
                    color: AppColors.borderSubtle,
                  ),
                  AppTile(
                    title: tr('Thêm tài khoản', 'Add account'),
                    leading: const AppAvatar(
                      radius: 22,
                      icon: Icons.add_rounded,
                    ),
                    onTap: () => _addAccount(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Firebase only keeps one currentUser and we never store credentials, so
  /// switching signs out first; the router then shows the sign-in screen.
  Future<void> _switchTo(
    BuildContext context,
    WidgetRef ref,
    StoredAccount account,
  ) async {
    final currentUid = ref.read(authStateProvider).valueOrNull?.uid;
    if (account.uid == currentUid) {
      Navigator.of(context).pop();
      return;
    }
    await ref.read(accountStoreProvider).setActive(account.uid);
    await ref.read(authServiceProvider).signOut();
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _addAccount(BuildContext context, WidgetRef ref) async {
    await ref.read(authServiceProvider).signOut();
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.isCurrent,
    required this.onSwitch,
    required this.onRemove,
  });

  final StoredAccount account;
  final bool isCurrent;
  final VoidCallback onSwitch;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AppTile(
      title: account.displayName,
      subtitle: account.email.isNotEmpty ? account.email : account.signInMethod,
      leading: AppAvatar(
        radius: 22,
        imageProvider: account.photoUrl != null
            ? NetworkImage(account.photoUrl!)
            : null,
      ),
      trailing: isCurrent
          ? const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: AppIconSize.lg,
            )
          : AppIconButton(
              icon: Icons.logout_rounded,
              size: AppIconSize.sm,
              tooltip: tr('Xoá khỏi danh sách', 'Remove from list'),
              onTap: onRemove,
            ),
      onTap: onSwitch,
    );
  }
}
