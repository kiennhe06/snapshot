import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/widgets/components/components.dart';
import '../../../models/login_session.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/empty_view.dart';
import '../../auth/providers/auth_providers.dart';

class LoginHistoryScreen extends ConsumerWidget {
  const LoginHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;

    return AppScaffold(
      topBar: const AppTopBar(title: 'Lịch sử đăng nhập', showBack: true),
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
                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: sessions.length,
                  itemBuilder: (_, i) => _SessionCard(
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

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onRevoke});

  final LoginSession session;
  final VoidCallback onRevoke;

  String _method(String code) => switch (code) {
    'password' => 'Email/Mật khẩu',
    'google.com' => 'Google',
    'phone' => 'Số điện thoại',
    _ => code,
  };

  Future<void> _confirmRevoke(BuildContext context) async {
    final ok = await showAppConfirm(
      context,
      title: 'Thu hồi phiên?',
      message:
          'Thiết bị "${session.deviceName}" sẽ bị đăng xuất khỏi tài khoản này.',
      confirmLabel: 'Thu hồi',
      destructive: true,
    );
    if (ok) onRevoke();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm', 'vi');
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.layer3,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              session.platform == 'ios'
                  ? Icons.phone_iphone_rounded
                  : Icons.phone_android_rounded,
              color: AppColors.primary,
              size: AppIconSize.lg,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        session.deviceName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppType.subhead,
                          fontWeight: AppType.medium,
                        ),
                      ),
                    ),
                    if (session.isCurrent) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const Text(
                          'Thiết bị này',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: AppType.small,
                            fontWeight: AppType.medium,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${session.osVersion} · ${_method(session.signInMethod)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppType.label,
                  ),
                ),
                Text(
                  'Đăng nhập: ${df.format(session.createdAt)}',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: AppType.label,
                  ),
                ),
              ],
            ),
          ),
          if (!session.isCurrent) ...[
            const SizedBox(width: AppSpacing.sm),
            AppIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Thu hồi phiên',
              color: AppColors.danger,
              onTap: () => _confirmRevoke(context),
            ),
          ],
        ],
      ),
    );
  }
}
