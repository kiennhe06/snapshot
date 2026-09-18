import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants.dart';
import '../../../../core/design/tokens.dart';
import '../../../../models/post.dart';
import '../../../../widgets/components/app_card.dart';
import '../../../../widgets/components/app_top_bar.dart';
import '../../../../widgets/components/press_scale.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../providers/feed_providers.dart';

/// A feed post as a custom depth card: author header, media carousel, like/
/// comment actions and caption. No Material ListTile/Card.
class PostCard extends ConsumerStatefulWidget {
  const PostCard({super.key, required this.post});

  final Post post;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final author = ref.watch(userProfileProvider(post.authorId)).valueOrNull;
    final isLiked =
        ref.watch(isLikedProvider(post.postId)).valueOrNull ?? false;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                PressScale(
                  onTap: () =>
                      context.push('${Routes.userProfile}/${post.authorId}'),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.layer3,
                    backgroundImage: author?.photoUrl != null
                        ? CachedNetworkImageProvider(author!.photoUrl!)
                        : null,
                    child: author?.photoUrl == null
                        ? const Icon(
                            Icons.person,
                            size: AppIconSize.md,
                            color: AppColors.textSecondary,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author?.username.isNotEmpty == true
                            ? author!.username
                            : (author?.displayName ?? '...'),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppType.subhead,
                          fontWeight: AppType.bold,
                        ),
                      ),
                      if (post.location != null)
                        Text(
                          post.location!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: AppType.small,
                          ),
                        ),
                    ],
                  ),
                ),
                AppIconButton(
                  icon: Icons.more_horiz_rounded,
                  onTap: () => _postMenu(context, post),
                ),
              ],
            ),
          ),

          // Media carousel
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                PageView.builder(
                  itemCount: post.media.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) {
                    final m = post.media[i];
                    if (m.type == 'video') {
                      return Container(
                        color: AppColors.layer3,
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_outline_rounded,
                            color: AppColors.primary,
                            size: 56,
                          ),
                        ),
                      );
                    }
                    return Semantics(
                      label: m.altText.isEmpty ? null : m.altText,
                      image: true,
                      child: CachedNetworkImage(
                        imageUrl: m.url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, _) =>
                            Container(color: AppColors.layer1),
                        errorWidget: (_, _, _) => const Icon(
                          Icons.broken_image_rounded,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    );
                  },
                ),
                if (post.media.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(post.media.length, (i) {
                        final active = i == _page;
                        return Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active
                                ? AppColors.primary
                                : AppColors.textPrimary.withValues(alpha: 0.5),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),

          // Actions + caption
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppIconButton(
                      icon: isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isLiked ? AppColors.primary : null,
                      tooltip: isLiked ? 'Bỏ thích' : 'Thích',
                      onTap: () {
                        final uid = ref
                            .read(authStateProvider)
                            .valueOrNull
                            ?.uid;
                        if (uid != null) {
                          ref
                              .read(feedRepositoryProvider)
                              .toggleLike(post.postId, uid);
                        }
                      },
                    ),
                    AppIconButton(
                      icon: Icons.mode_comment_outlined,
                      tooltip: 'Bình luận',
                      onTap: post.commentsDisabled
                          ? null
                          : () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Bình luận sẽ có ở giai đoạn sau.',
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!post.likesHidden)
                        Text(
                          '${post.likesCount} lượt thích',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: AppType.body,
                            fontWeight: AppType.bold,
                          ),
                        ),
                      if (post.caption.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: AppType.body,
                                height: 1.35,
                              ),
                              children: [
                                TextSpan(
                                  text: author?.username.isNotEmpty == true
                                      ? '${author!.username} '
                                      : '',
                                  style: const TextStyle(
                                    fontWeight: AppType.bold,
                                  ),
                                ),
                                TextSpan(text: post.caption),
                              ],
                            ),
                          ),
                        ),
                      if (!post.commentsDisabled && post.commentsCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            'Xem tất cả ${post.commentsCount} bình luận',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: AppType.label,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          DateFormat(
                            'dd/MM/yyyy HH:mm',
                            'vi',
                          ).format(post.createdAt),
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: AppType.small,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _postMenu(BuildContext context, Post post) {
    final favorites = ref.read(favoriteIdsProvider).valueOrNull ?? const [];
    final isFav = favorites.contains(post.authorId);
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                isFav ? Icons.star_rounded : Icons.star_border_rounded,
              ),
              title: Text(
                isFav ? 'Bỏ khỏi Yêu thích' : 'Thêm vào Yêu thích (Favorites)',
              ),
              onTap: () async {
                Navigator.pop(context);
                if (uid != null) {
                  await ref
                      .read(feedRepositoryProvider)
                      .setFavorite(
                        uid: uid,
                        targetUid: post.authorId,
                        favorite: !isFav,
                      );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Xem trang cá nhân'),
              onTap: () {
                Navigator.pop(context);
                context.push('${Routes.userProfile}/${post.authorId}');
              },
            ),
          ],
        ),
      ),
    );
  }
}
