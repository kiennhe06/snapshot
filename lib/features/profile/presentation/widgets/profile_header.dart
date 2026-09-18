import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/widgets/components/components.dart';
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                imageProvider: user.photoUrl != null
                    ? CachedNetworkImageProvider(user.photoUrl!)
                    : null,
                radius: 40,
                icon: Icons.person_rounded,
              ),
              const SizedBox(width: AppSpacing.xl),
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
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                user.displayName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppType.headline,
                  fontWeight: AppType.bold,
                ),
              ),
              if (user.isVerified) ...[
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.verified_rounded,
                  size: AppIconSize.sm,
                  color: AppColors.primary,
                ),
              ],
              if (user.isPrivate) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.lock_outline_rounded,
                  size: AppIconSize.xs,
                  color: AppColors.textTertiary,
                ),
              ],
            ],
          ),
          if (user.username.isNotEmpty)
            Text(
              '@${user.username}',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: AppType.body,
              ),
            ),
          if (user.bio.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              user.bio,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppType.subhead,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: isMe
                    ? AppButton(
                        label: 'Chỉnh sửa hồ sơ',
                        variant: AppButtonVariant.secondary,
                        height: 46,
                        onPressed: onEditProfile,
                      )
                    : AppButton(
                        label: isFollowing ? 'Đang theo dõi' : 'Theo dõi',
                        variant: isFollowing
                            ? AppButtonVariant.secondary
                            : AppButtonVariant.primary,
                        height: 46,
                        onPressed: onToggleFollow,
                      ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppIconButton(
                icon: Icons.qr_code_rounded,
                tooltip: 'Nametag',
                onTap: onShowQr,
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
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppType.title,
            fontWeight: AppType.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppType.label,
          ),
        ),
      ],
    );
  }
}
