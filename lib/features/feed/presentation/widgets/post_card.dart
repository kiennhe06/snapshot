import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:share_plus/share_plus.dart';

import '../../../../core/constants.dart';
import '../../../../core/design/tokens.dart';
import 'package:snapshot/core/i18n/i18n.dart';
import '../../../../models/post.dart';
import '../../../../widgets/components/components.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../interactions/presentation/comments_screen.dart';
import '../../../interactions/providers/interaction_providers.dart';
import '../../../messages/presentation/share_to_chat_sheet.dart';
import '../../../../models/chat.dart';
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
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    final isMine = uid == post.authorId;
    final isFollowing =
        ref.watch(isFollowingProvider(post.authorId)).valueOrNull ?? false;
    final name = author?.username.isNotEmpty == true
        ? author!.username
        : (author?.displayName ?? '...');

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar · name+verified+location · Follow · menu
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                PressScale(
                  onTap: () =>
                      context.push('${Routes.userProfile}/${post.authorId}'),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.primaryBright, AppColors.primary],
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 19,
                      backgroundColor: AppColors.layer3,
                      backgroundImage: author?.photoUrl != null
                          ? CachedNetworkImageProvider(author!.photoUrl!)
                          : null,
                      child: author?.photoUrl == null
                          ? Icon(
                              Icons.person,
                              size: AppIconSize.md,
                              color: AppColors.textSecondary,
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: AppType.subhead,
                                fontWeight: AppType.bold,
                              ),
                            ),
                          ),
                          if (author?.isVerified == true) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.verified_rounded,
                              size: AppIconSize.sm,
                              color: AppColors.accent,
                            ),
                          ],
                          if (!isMine && !isFollowing) ...[
                            const SizedBox(width: AppSpacing.sm),
                            PressScale(
                              onTap: () {
                                if (uid != null) {
                                  ref
                                      .read(followRepositoryProvider)
                                      .follow(
                                        currentUid: uid,
                                        targetUid: post.authorId,
                                      );
                                }
                              },
                              child: Text(
                                tr('Theo dõi', 'Follow'),
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: AppType.label,
                                  fontWeight: AppType.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (post.location != null && post.location!.isNotEmpty)
                        Text(
                          post.location!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
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

          // Media carousel — inset rounded "print" with a 1/N index badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: AspectRatio(
                aspectRatio: 4 / 5,
                child: Stack(
                  fit: StackFit.expand,
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
                                Container(color: AppColors.layer3),
                            errorWidget: (_, _, _) => Icon(
                              Icons.broken_image_rounded,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        );
                      },
                    ),
                    if (post.media.length > 1)
                      Positioned(
                        top: AppSpacing.sm,
                        right: AppSpacing.sm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '${_page + 1}/${post.media.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: AppType.small,
                              fontWeight: AppType.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Actions with counts
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Row(
              children: [
                _CountAction(
                  icon: isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isLiked ? AppColors.primary : AppColors.textPrimary,
                  label: post.likesHidden ? null : _fmtCount(post.likesCount),
                  onTap: () {
                    if (uid != null) {
                      ref
                          .read(feedRepositoryProvider)
                          .toggleLike(post.postId, uid);
                    }
                  },
                ),
                const SizedBox(width: AppSpacing.lg),
                _CountAction(
                  icon: Icons.mode_comment_outlined,
                  color: AppColors.textPrimary,
                  label: '${post.commentsCount}',
                  onTap: post.commentsDisabled
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CommentsScreen(post: post),
                          ),
                        ),
                ),
                const SizedBox(width: AppSpacing.lg),
                _CountAction(
                  icon: Icons.send_outlined,
                  color: AppColors.textPrimary,
                  onTap: () => showAppMenu(context, [
                    AppMenuAction(
                      icon: Icons.mail_outline_rounded,
                      label: tr('Gửi trong tin nhắn', 'Send in message'),
                      onTap: () => showShareToChatSheet(
                        context,
                        type: MessageType.post,
                        refId: post.postId,
                      ),
                    ),
                    AppMenuAction(
                      icon: Icons.ios_share_rounded,
                      label: tr('Chia sẻ khác', 'Share via...'),
                      onTap: () => Share.share(
                        'Xem bài viết trên Snapshot: snapshot://user/${post.authorId}',
                      ),
                    ),
                  ]),
                ),
                const Spacer(),
                AppIconButton(
                  icon: isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: isSaved ? AppColors.primary : null,
                  onTap: () {
                    if (uid != null) {
                      ref
                          .read(saveRepositoryProvider)
                          .toggleSave(uid: uid, postId: post.postId);
                    }
                  },
                ),
              ],
            ),
          ),

          // Caption + hashtags + view-comments + time
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.caption.isNotEmpty)
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: AppType.body,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: '$name ',
                          style: const TextStyle(fontWeight: AppType.bold),
                        ),
                        ..._captionSpans(post.caption),
                      ],
                    ),
                  ),
                if (!post.commentsDisabled && post.commentsCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: PressScale(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CommentsScreen(post: post),
                        ),
                      ),
                      child: Text(
                        tr(
                          'Xem tất cả ${post.commentsCount} bình luận',
                          'View all ${post.commentsCount} comments',
                        ),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppType.label,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    _relTime(post.createdAt),
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: AppType.small,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Spotify music chip
          if (post.hasMusic) _MusicChip(post: post),

          // Inline quick-comment prompt + emoji reactions
          if (!post.commentsDisabled)
            _QuickComment(post: post, authorName: name),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  /// Colour hashtags inside a caption.
  List<TextSpan> _captionSpans(String caption) {
    final spans = <TextSpan>[];
    for (final token in caption.split(RegExp(r'(\s+)'))) {
      if (token.startsWith('#') && token.length > 1) {
        spans.add(
          TextSpan(
            text: token,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: AppType.medium,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: token));
      }
      spans.add(const TextSpan(text: ' '));
    }
    return spans;
  }

  /// 2400 → "2,4K", 5000 → "5K", 890 → "890".
  String _fmtCount(int n) {
    if (n < 1000) return '$n';
    final k = (n / 1000).toStringAsFixed(1).replaceAll('.', ',');
    return '${k.endsWith(',0') ? k.substring(0, k.length - 2) : k}K';
  }

  String _relTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return tr('vừa xong', 'just now');
    if (d.inMinutes < 60) return tr('${d.inMinutes} phút trước', '${d.inMinutes}m ago');
    if (d.inHours < 24) return tr('${d.inHours} giờ trước', '${d.inHours}h ago');
    if (d.inDays < 7) return tr('${d.inDays} ngày trước', '${d.inDays}d ago');
    return DateFormat('dd/MM/yyyy').format(t);
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
            showAppToast(
              context,
              tr('Đã gửi báo cáo.', 'Report sent.'),
              type: AppToastType.success,
            );
          },
        ),
      ],
    ]);
  }
}

/// An icon with an inline count (like / comment / share), à la VibeFeed.
class _CountAction extends StatelessWidget {
  const _CountAction({
    required this.icon,
    required this.color,
    this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 26, color: onTap == null ? AppColors.textTertiary : color),
          if (label != null && label!.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              label!,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppType.body,
                fontWeight: AppType.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Inline "add a comment" row with quick emoji reactions.
class _QuickComment extends ConsumerWidget {
  const _QuickComment({required this.post, required this.authorName});
  final Post post;
  final String authorName;

  static const _emojis = ['❤️', '🔥', '😍', '👏', '😮'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myProfileProvider).valueOrNull;

    Future<void> react(String emoji) async {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid == null) return;
      await ref
          .read(commentRepositoryProvider)
          .addComment(postId: post.postId, uid: uid, text: emoji);
      if (context.mounted) {
        showAppToast(context, tr('Đã gửi $emoji', 'Sent $emoji'));
      }
    }

    void openComments() => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CommentsScreen(post: post)),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppColors.layer3,
            backgroundImage: me?.photoUrl != null
                ? CachedNetworkImageProvider(me!.photoUrl!)
                : null,
            child: me?.photoUrl == null
                ? Icon(Icons.person, size: AppIconSize.sm, color: AppColors.textSecondary)
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: PressScale(
              onTap: openComments,
              child: Text(
                tr('Thêm bình luận cho $authorName…', 'Add a comment for $authorName…'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: AppType.label,
                ),
              ),
            ),
          ),
          for (final e in _emojis)
            PressScale(
              onTap: () => react(e),
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Text(e, style: const TextStyle(fontSize: 17)),
              ),
            ),
        ],
      ),
    );
  }
}

/// A Spotify music chip on a post: album art + title/artist. Plays the 30s
/// preview when Spotify provides one, otherwise opens the track in Spotify.
class _MusicChip extends StatefulWidget {
  const _MusicChip({required this.post});
  final Post post;

  @override
  State<_MusicChip> createState() => _MusicChipState();
}

class _MusicChipState extends State<_MusicChip> {
  AudioPlayer? _player;
  bool _playing = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    final p = widget.post;
    final preview = p.musicPreviewUrl;
    if (preview != null && preview.isNotEmpty) {
      _player ??= AudioPlayer()
        ..onPlayerComplete.listen((_) {
          if (mounted) setState(() => _playing = false);
        });
      if (_playing) {
        await _player!.pause();
        if (mounted) setState(() => _playing = false);
      } else {
        await _player!.play(UrlSource(preview));
        if (mounted) setState(() => _playing = true);
      }
    } else if (p.musicUrl != null && p.musicUrl!.isNotEmpty) {
      final uri = Uri.tryParse(p.musicUrl!);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final hasPreview = (p.musicPreviewUrl ?? '').isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: PressScale(
        onTap: _onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.layer3,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: (p.musicCoverUrl ?? '').isEmpty
                    ? Container(
                        width: 30,
                        height: 30,
                        color: AppColors.layer1,
                        child: Icon(
                          Icons.music_note_rounded,
                          size: AppIconSize.sm,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: p.musicCoverUrl!,
                        width: 30,
                        height: 30,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  '${p.musicTitle} · ${p.musicArtist ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppType.label,
                    fontWeight: AppType.medium,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                hasPreview
                    ? (_playing
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded)
                    : Icons.open_in_new_rounded,
                size: AppIconSize.md,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
