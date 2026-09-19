import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/core/i18n/i18n.dart';
import 'package:snapshot/widgets/components/components.dart';
import '../providers/profile_providers.dart';

/// Displays a scannable nametag QR code that encodes the user's profile link.
/// Another user can scan `snapshot://user/{uid}` to open this profile.
class QrNametagScreen extends ConsumerWidget {
  const QrNametagScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider(uid)).valueOrNull;
    final link = 'snapshot://user/$uid';
    final username = user?.username.isNotEmpty == true
        ? '@${user!.username}'
        : (user?.displayName ?? '');

    return AppScaffold(
      topBar: const AppTopBar(title: 'Nametag', showBack: true),
      body: Center(
        child: AppCard(
          margin: const EdgeInsets.all(AppSpacing.xxl),
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                username,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppType.title,
                  fontWeight: AppType.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              QrImageView(
                data: link,
                version: QrVersions.auto,
                size: 220,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.circle,
                  color: AppColors.primary,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                tr(
                  'Cho bạn bè quét mã này để mở hồ sơ của bạn.',
                  'Let friends scan this code to open your profile.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppType.subhead,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
