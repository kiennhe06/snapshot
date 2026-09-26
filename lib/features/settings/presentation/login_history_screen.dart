import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/core/i18n/i18n.dart';
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
      topBar: AppTopBar(
        title: tr('Lịch sử đăng nhập', 'Login history'),
        showBack: true,
      ),
      body: uid == null
          ? EmptyView(
              message: tr('Bạn chưa đăng nhập.', 'You are not signed in.'),
            )
          : AsyncValueView<List<LoginSession>>(
              value: ref.watch(sessionsProvider(uid)),
              onRetry: () => ref.invalidate(sessionsProvider(uid)),
              builder: (sessions) {
                if (sessions.isEmpty) {
                  return EmptyView(
                    message: tr(
                      'Chưa có phiên đăng nhập nào được ghi lại.',
                      'No login sessions have been recorded yet.',
                    ),
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
    'password' => tr('Email/Mật khẩu', 'Email/Password'),
    'google.com' => 'Google',
    'phone' => tr('Số điện thoại', 'Phone'),
    _ => code,
  };

  Future<void> _confirmRevoke(BuildContext context) async {
    final ok = await showAppConfirm(
      context,
      title: tr('Thu hồi phiên?', 'Revoke session?'),
      message: tr(
        'Thiết bị "${session.deviceName}" sẽ bị đăng xuất khỏi tài khoản này.',
        'The device "${session.deviceName}" will be signed out of this account.',
      ),
      confirmLabel: tr('Thu hồi', 'Revoke'),
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
                        style: TextStyle(
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
                        child: Text(
                          tr('Thiết bị này', 'This device'),
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
                  style: AppText.label,
                ),
                Text(
                  tr(
                    'Đăng nhập: ${df.format(session.createdAt)}',
                    'Signed in: ${df.format(session.createdAt)}',
                  ),
                  style: TextStyle(
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
              tooltip: tr('Thu hồi phiên', 'Revoke session'),
              color: AppColors.danger,
              onTap: () => _confirmRevoke(context),
            ),
          ],
        ],
      ),
    );
  }
}
