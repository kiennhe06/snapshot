import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/login_session.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/empty_view.dart';
import '../../auth/providers/auth_providers.dart';

class LoginHistoryScreen extends ConsumerWidget {
  const LoginHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử đăng nhập')),
      body: uid == null
          ? const EmptyView(message: 'Bạn chưa đăng nhập.')
          : AsyncValueView<List<LoginSession>>(
              value: ref.watch(sessionsProvider(uid)),
              onRetry: () => ref.invalidate(sessionsProvider(uid)),
              builder: (sessions) {
                if (sessions.isEmpty) {
                  return const EmptyView(
                    message: 'Chưa có phiên đăng nhập nào được ghi lại.',
                    icon: Icons.devices_other,
                  );
                }
                return ListView.separated(
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => _SessionTile(
                    session: sessions[i],
                    onRevoke: () => ref
                        .read(sessionServiceProvider)
                        .revokeSession(uid, sessions[i].sessionId),
                  ),
                );
              },
            ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onRevoke});

  final LoginSession session;
  final VoidCallback onRevoke;

  String _method(String code) => switch (code) {
    'password' => 'Email/Mật khẩu',
    'google.com' => 'Google',
    'phone' => 'Số điện thoại',
    _ => code,
  };

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm', 'vi');
    return ListTile(
      leading: Icon(
        session.platform == 'ios' ? Icons.phone_iphone : Icons.phone_android,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(session.deviceName, overflow: TextOverflow.ellipsis),
          ),
          if (session.isCurrent) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Thiết bị này', style: TextStyle(fontSize: 11)),
            ),
          ],
        ],
      ),
      subtitle: Text(
        '${session.osVersion} · ${_method(session.signInMethod)}\n'
        'Đăng nhập: ${df.format(session.createdAt)}',
      ),
      isThreeLine: true,
      trailing: session.isCurrent
          ? null
          : IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Thu hồi phiên',
              onPressed: onRevoke,
            ),
    );
  }
}
