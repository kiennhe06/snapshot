import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/stored_account.dart';
import '../providers/auth_providers.dart';

/// Shows the multi-account switcher as a modal bottom sheet.
Future<void> showAccountSwitcher(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _AccountSwitcherSheet(),
  );
}

class _AccountSwitcherSheet extends ConsumerWidget {
  const _AccountSwitcherSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: accountsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Không tải được danh sách tài khoản.'),
          ),
          data: (accounts) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  'Tài khoản',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              ...accounts.map(
                (a) => _AccountTile(
                  account: a,
                  isCurrent: a.uid == currentUid,
                  onSwitch: () => _switchTo(context, ref, a),
                  onRemove: () =>
                      ref.read(accountsProvider.notifier).remove(a.uid),
                ),
              ),
              const Divider(height: 8),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Thêm tài khoản'),
                onTap: () => _addAccount(context, ref),
              ),
            ],
          ),
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
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: account.photoUrl != null
            ? NetworkImage(account.photoUrl!)
            : null,
        child: account.photoUrl == null
            ? Text(
                account.displayName.isNotEmpty
                    ? account.displayName[0].toUpperCase()
                    : '?',
              )
            : null,
      ),
      title: Text(account.displayName),
      subtitle: Text(
        account.email.isNotEmpty ? account.email : account.signInMethod,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isCurrent
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : IconButton(
              icon: const Icon(Icons.logout, size: 20),
              tooltip: 'Xoá khỏi danh sách',
              onPressed: onRemove,
            ),
      onTap: onSwitch,
    );
  }
}
