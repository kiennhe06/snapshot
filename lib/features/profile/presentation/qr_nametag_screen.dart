import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Nametag')),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                QrImageView(
                  data: link,
                  version: QrVersions.auto,
                  size: 220,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Cho bạn bè quét mã này để mở hồ sơ của bạn.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
