import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../models/app_user.dart';

/// Profile header: avatar, counts, name/bio/website and the primary action.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.user,
    required this.isMe,
    required this.postsCount,
    this.isFollowing = false,
    this.onEditProfile,
    this.onToggleFollow,
    this.onShowQr,
  });

  final AppUser user;
  final bool isMe;
  final int postsCount;
  final bool isFollowing;
  final VoidCallback? onEditProfile;
  final VoidCallback? onToggleFollow;
  final VoidCallback? onShowQr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: user.photoUrl != null
                    ? CachedNetworkImageProvider(user.photoUrl!)
                    : null,
                child: user.photoUrl == null
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Stat(count: postsCount, label: 'Bài viết'),
                    _Stat(count: user.followersCount, label: 'Người theo dõi'),
                    _Stat(count: user.followingCount, label: 'Đang theo dõi'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                user.displayName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (user.isVerified) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.verified,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ],
              if (user.isPrivate) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: theme.colorScheme.outline,
                ),
              ],
            ],
          ),
          if (user.username.isNotEmpty)
            Text(
              '@${user.username}',
              style: TextStyle(color: theme.colorScheme.outline),
            ),
          if (user.bio.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(user.bio),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: isMe
                    ? OutlinedButton(
                        onPressed: onEditProfile,
                        child: const Text('Chỉnh sửa hồ sơ'),
                      )
                    : FilledButton(
                        onPressed: onToggleFollow,
                        style: isFollowing
                            ? FilledButton.styleFrom(
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                                foregroundColor: theme.colorScheme.onSurface,
                              )
                            : null,
                        child: Text(isFollowing ? 'Đang theo dõi' : 'Theo dõi'),
                      ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onShowQr,
                child: const Icon(Icons.qr_code, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.count, required this.label});
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
