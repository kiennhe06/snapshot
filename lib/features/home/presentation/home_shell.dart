import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../auth/presentation/account_switcher_sheet.dart';
import '../../auth/providers/auth_providers.dart';

/// Placeholder home for Phase 1. Feed / post / profile tabs arrive in later
/// phases; for now this is where account & security actions live so the auth
/// flow is testable end-to-end.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi tài khoản này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authServiceProvider).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Snapshot'),
        actions: [
          IconButton(
            icon: const Icon(Icons.switch_account),
            tooltip: 'Chuyển tài khoản',
            onPressed: () => showAccountSwitcher(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: user?.photoURL == null ? const Icon(Icons.person) : null,
              ),
              title: Text(user?.displayName ?? user?.email ?? 'Người dùng'),
              subtitle: Text(user?.email ?? user?.phoneNumber ?? ''),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Bật xác thực 2 lớp (2FA)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.mfaEnroll),
          ),
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text('Lịch sử đăng nhập / thiết bị'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.loginHistory),
          ),
          ListTile(
            leading: const Icon(Icons.switch_account),
            title: const Text('Quản lý / chuyển tài khoản'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showAccountSwitcher(context),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Đăng xuất',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _confirmSignOut(context, ref),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Bảng tin, đăng ảnh/video và hồ sơ sẽ có ở các giai đoạn sau.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
