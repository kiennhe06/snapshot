import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:share_plus/share_plus.dart';

import '../../../../core/constants.dart';
import '../../../../core/design/tokens.dart';
import 'package:snapshot/core/i18n/i18n.dart';
import '../../../../models/post.dart';
import '../../../../widgets/components/components.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../interactions/presentation/comments_screen.dart';
import '../../../interactions/providers/interaction_providers.dart';
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
    final isSaved =
        ref.watch(isSavedProvider(post.postId)).valueOrNull ?? false;

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
                      return AppVideo(url: m.url, active: false, muted: true);
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
                      tooltip: isLiked
                          ? tr('Bỏ thích', 'Unlike')
                          : tr('Thích', 'Like'),
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
                      tooltip: tr('Bình luận', 'Comment'),
                      onTap: post.commentsDisabled
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CommentsScreen(post: post),
                              ),
                            ),
                    ),
                    AppIconButton(
                      icon: Icons.send_outlined,
                      tooltip: tr('Chia sẻ', 'Share'),
                      onTap: () => Share.share(
                        'Xem bài viết trên Snapshot: snapshot://user/${post.authorId}',
                      ),
                    ),
                    const Spacer(),
                    AppIconButton(
                      icon: isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: isSaved ? AppColors.primary : null,
                      tooltip: isSaved
                          ? tr('Bỏ lưu', 'Unsave')
                          : tr('Lưu bài', 'Save'),
                      onTap: () {
                        final uid = ref
                            .read(authStateProvider)
                            .valueOrNull
                            ?.uid;
                        if (uid != null) {
                          ref
                              .read(saveRepositoryProvider)
                              .toggleSave(uid: uid, postId: post.postId);
                        }
                      },
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
                          tr(
                            '${post.likesCount} lượt thích',
                            '${post.likesCount} likes',
                          ),
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
                            tr(
                              'Xem tất cả ${post.commentsCount} bình luận',
                              'View all ${post.commentsCount} comments',
                            ),
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
    final isMine = uid == post.authorId;
    final blocked = (ref.read(blockedIdsProvider).valueOrNull ?? const [])
        .contains(post.authorId);
    final muted = (ref.read(mutedIdsProvider).valueOrNull ?? const []).contains(
      post.authorId,
    );
    final restricted = (ref.read(restrictedIdsProvider).valueOrNull ?? const [])
        .contains(post.authorId);
    final rel = ref.read(relationRepositoryProvider);

    showAppMenu(context, [
      AppMenuAction(
        icon: isFav ? Icons.star_rounded : Icons.star_border_rounded,
        label: isFav
            ? tr('Bỏ khỏi Yêu thích', 'Remove from Favorites')
            : tr('Thêm vào Yêu thích', 'Add to Favorites'),
        onTap: () {
          if (uid != null) {
            ref
                .read(feedRepositoryProvider)
                .setFavorite(
                  uid: uid,
                  targetUid: post.authorId,
                  favorite: !isFav,
                );
          }
        },
      ),
      AppMenuAction(
        icon: Icons.person_outline_rounded,
        label: tr('Xem trang cá nhân', 'View profile'),
        onTap: () => context.push('${Routes.userProfile}/${post.authorId}'),
      ),
      if (!isMine) ...[
        AppMenuAction(
          icon: restricted ? Icons.shield : Icons.shield_outlined,
          label: restricted
              ? tr('Bỏ hạn chế', 'Unrestrict')
              : tr('Hạn chế (Restrict)', 'Restrict'),
          onTap: () {
            if (uid != null) {
              rel.setRelation(
                uid: uid,
                kind: 'restricted',
                targetUid: post.authorId,
                on: !restricted,
              );
            }
          },
        ),
        AppMenuAction(
          icon: muted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          label: muted
              ? tr('Bỏ tắt tiếng', 'Unmute')
              : tr('Tắt tiếng (Mute)', 'Mute'),
          onTap: () {
            if (uid != null) {
              rel.setRelation(
                uid: uid,
                kind: 'muted',
                targetUid: post.authorId,
                on: !muted,
              );
            }
          },
        ),
        AppMenuAction(
          icon: Icons.block_rounded,
          label: blocked
              ? tr('Bỏ chặn', 'Unblock')
              : tr('Chặn người này', 'Block this person'),
          destructive: !blocked,
          onTap: () {
            if (uid != null) {
              rel.setRelation(
                uid: uid,
                kind: 'blocked',
                targetUid: post.authorId,
                on: !blocked,
              );
            }
          },
        ),
        AppMenuAction(
          icon: Icons.flag_outlined,
          label: tr('Báo cáo bài viết', 'Report post'),
          destructive: true,
          onTap: () {
            if (uid != null) {
              rel.report(
                reporterId: uid,
                targetType: 'post',
                targetId: post.postId,
                reason: 'reported from feed',
              );
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr('Đã gửi báo cáo.', 'Report sent.'))),
            );
          },
        ),
      ],
    ]);
  }
}
