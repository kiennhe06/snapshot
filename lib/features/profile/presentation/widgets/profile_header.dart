import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/core/i18n/i18n.dart';
import 'package:snapshot/core/utils/format.dart';
import 'package:snapshot/widgets/components/components.dart';
import '../../../../models/app_user.dart';
import '../follow_list_screen.dart';

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
    this.onChangeAvatar,
  });

  final AppUser user;
  final bool isMe;
  final int postsCount;
  final bool isFollowing;
  final VoidCallback? onEditProfile;
  final VoidCallback? onToggleFollow;
  final VoidCallback? onShowQr;

  /// Tapping the owner's avatar picks a new photo and uploads it immediately.
  final VoidCallback? onChangeAvatar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AvatarSlot(
                user: user,
                isMe: isMe,
                onChangeAvatar: onChangeAvatar,
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Stat(count: postsCount, label: tr('Bài viết', 'Posts')),
                    _Stat(
                      count: user.followersCount,
                      label: tr('Người theo dõi', 'Followers'),
                      onTap: () => _openFollowList(context, true),
                    ),
                    _Stat(
                      count: user.followingCount,
                      label: tr('Đang theo dõi', 'Following'),
                      onTap: () => _openFollowList(context, false),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Flexible(
                child: Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.h2,
                ),
              ),
              if (user.isVerified) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.verified_rounded,
                  size: AppIconSize.sm,
                  color: AppColors.primary,
                ),
              ],
              if (user.isPrivate) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body.copyWith(color: AppColors.textTertiary),
            ),
          if (user.bio.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              user.bio,
              style: TextStyle(
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
                        label: tr('Chỉnh sửa hồ sơ', 'Edit profile'),
                        variant: AppButtonVariant.secondary,
                        height: 46,
                        onPressed: onEditProfile,
                      )
                    : AppButton(
                        label: isFollowing
                            ? tr('Đang theo dõi', 'Following')
                            : tr('Theo dõi', 'Follow'),
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

  void _openFollowList(BuildContext context, bool followers) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FollowListScreen(
          uid: user.uid,
          username: user.username,
          showFollowers: followers,
        ),
      ),
    );
  }
}

/// The profile avatar. For the signed-in owner it is tappable and shows a
/// small camera badge, signalling that tapping changes the profile photo.
class _AvatarSlot extends StatelessWidget {
  const _AvatarSlot({
    required this.user,
    required this.isMe,
    required this.onChangeAvatar,
  });

  final AppUser user;
  final bool isMe;
  final VoidCallback? onChangeAvatar;

  @override
  Widget build(BuildContext context) {
    final avatar = AppAvatar(
      imageProvider: user.photoUrl != null
          ? CachedNetworkImageProvider(user.photoUrl!)
          : null,
      radius: 40,
      icon: Icons.person_rounded,
    );

    if (!isMe) return avatar;

    return PressScale(
      onTap: onChangeAvatar,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryBright],
                ),
                border: Border.all(color: AppColors.scaffold, width: 2.5),
              ),
              child: const Icon(
                Icons.add_a_photo_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.count, required this.label, this.onTap});
  final int count;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Column(
      children: [
        Text(
          formatCount(count),
          style: AppText.h1,
        ),
        Text(
          label,
          style: AppText.label,
        ),
      ],
      ),
    );
  }
}
