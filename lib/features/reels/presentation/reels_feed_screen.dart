import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/utils/format.dart';
import '../../../models/chat.dart';
import '../../../models/post.dart';
import '../../../widgets/components/components.dart';
import '../../messages/presentation/share_to_chat_sheet.dart';
import '../../../widgets/empty_view.dart';
import '../../../widgets/loading_view.dart';
import '../../auth/providers/auth_providers.dart';
import '../../feed/providers/feed_providers.dart';
import '../../interactions/presentation/comments_screen.dart';
import '../../interactions/providers/interaction_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/reels_providers.dart';
import 'music_page_screen.dart';
import 'reel_composer_screen.dart';

/// Full-screen vertical reels feed with real video playback.
class ReelsFeedScreen extends ConsumerStatefulWidget {
  const ReelsFeedScreen({super.key});

  @override
  ConsumerState<ReelsFeedScreen> createState() => _ReelsFeedScreenState();
}

class _ReelsFeedScreenState extends ConsumerState<ReelsFeedScreen> {
  final _page = PageController();
  int _index = 0;
  bool _muted = false;
  ReelsTab _tab = ReelsTab.forYou;

  void _selectTab(ReelsTab tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _index = 0;
    });
    if (_page.hasClients) _page.jumpToPage(0);
    ref.read(reelsControllerProvider.notifier).setTab(tab);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reelsControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Builder(
        builder: (_) {
          if (!state.initialized && state.isLoading) return const LoadingView();
          if (state.posts.isEmpty) {
            return Stack(
              children: [
                Center(
                  child: EmptyView(
                    message: tr(
                      'Chưa có reels nào.\nĐăng video đầu tiên!',
                      'No reels yet.\nShare the first video!',
                    ),
                    icon: Icons.movie_creation_outlined,
                  ),
                ),
                _topBar(),
              ],
            );
          }
          return Stack(
            children: [
              PageView.builder(
                controller: _page,
                scrollDirection: Axis.vertical,
                itemCount: state.posts.length,
                onPageChanged: (i) {
                  setState(() => _index = i);
                  if (i >= state.posts.length - 2) {
                    ref.read(reelsControllerProvider.notifier).loadMore();
                  }
                },
                itemBuilder: (_, i) => _ReelPage(
                  post: state.posts[i],
                  active: i == _index,
                  muted: _muted,
                  onToggleMute: () => setState(() => _muted = !_muted),
                ),
              ),
              _topBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _topBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            const SizedBox(width: 40), // balance the create button
            const Spacer(),
            _tabLabel(tr('Dành cho bạn', 'For you'), ReelsTab.forYou),
            const SizedBox(width: AppSpacing.lg),
            _tabLabel(tr('Đang theo dõi', 'Following'), ReelsTab.following),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.videocam_rounded, color: Colors.white),
              tooltip: tr('Tạo reel', 'Create reel'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReelComposerScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabLabel(String label, ReelsTab tab) {
    final selected = _tab == tab;
    return PressScale(
      onTap: () => _selectTab(tab),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white60,
              fontSize: AppType.subhead,
              fontWeight: selected ? AppType.heavy : AppType.medium,
              shadows: const [Shadow(color: Colors.black45, blurRadius: 8)],
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 2.5,
            width: selected ? 20 : 0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelPage extends ConsumerWidget {
  const _ReelPage({
    required this.post,
    required this.active,
    required this.muted,
    required this.onToggleMute,
  });

  final Post post;
  final bool active;
  final bool muted;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = ref.watch(userProfileProvider(post.authorId)).valueOrNull;
    final isSaved =
        ref.watch(isSavedProvider(post.postId)).valueOrNull ?? false;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    final isMine = post.authorId == uid;
    final isFollowing =
        ref.watch(isFollowingProvider(post.authorId)).valueOrNull ?? false;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video
        if (post.media.isNotEmpty)
          AppVideo(
            url: post.media.first.url,
            active: active,
            muted: muted,
            showProgress: true,
          )
        else
          const ColoredBox(color: Colors.black),

        // Right actions
        Positioned(
          right: AppSpacing.md,
          bottom: 96,
          child: Column(
            children: [
              _ReelLikeButton(post: post, uid: uid),
              _action(
                icon: Icons.mode_comment_outlined,
                color: Colors.white,
                label: formatCount(post.commentsCount),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CommentsScreen(post: post)),
                ),
              ),
              _action(
                icon: Icons.send_outlined,
                color: Colors.white,
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
                      'Snapshot reel: snapshot://user/${post.authorId}',
                    ),
                  ),
                ]),
              ),
              _action(
                icon: isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: isSaved ? AppColors.primary : Colors.white,
                onTap: () {
                  if (uid != null) {
                    ref
                        .read(saveRepositoryProvider)
                        .toggleSave(uid: uid, postId: post.postId);
                  }
                },
              ),
              _action(
                icon: Icons.auto_awesome_motion_outlined,
                color: Colors.white,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReelComposerScreen(
                      remixOfPostId: post.postId,
                      music: post.musicTitle,
                    ),
                  ),
                ),
              ),
              _action(
                icon: muted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                color: Colors.white,
                onTap: onToggleMute,
              ),
              if (post.musicTitle != null)
                PressScale(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          MusicPageScreen(musicTitle: post.musicTitle!),
                    ),
                  ),
                  child: _SpinningDisc(
                    coverUrl: post.musicCoverUrl,
                    spinning: active && !muted,
                  ),
                ),
            ],
          ),
        ),

        // Bottom info
        Positioned(
          left: AppSpacing.md,
          right: 72,
          bottom: AppSpacing.xl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.layer3,
                    backgroundImage: author?.photoUrl != null
                        ? CachedNetworkImageProvider(author!.photoUrl!)
                        : null,
                    child: author?.photoUrl == null
                        ? const Icon(
                            Icons.person,
                            size: 18,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      author?.username.isNotEmpty == true
                          ? '@${author!.username}'
                          : (author?.displayName ?? ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: AppType.bold,
                        fontSize: AppType.subhead,
                      ),
                    ),
                  ),
                  if (author?.isVerified == true) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.verified_rounded,
                      size: 15,
                      color: AppColors.accent,
                    ),
                  ],
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    relativeTime(post.createdAt, short: true),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: AppType.label,
                    ),
                  ),
                  if (!isMine && !isFollowing) ...[
                    const SizedBox(width: AppSpacing.sm),
                    PressScale(
                      onTap: () {
                        if (uid != null) {
                          ref
                              .read(followRepositoryProvider)
                              .follow(currentUid: uid, targetUid: post.authorId);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          tr('Theo dõi', 'Follow'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: AppType.label,
                            fontWeight: AppType.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (post.caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: _CaptionText(caption: post.caption),
                ),
              if (post.remixOfPostId != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: _tagPill(
                    Icons.auto_awesome_motion,
                    tr('Remix', 'Remix'),
                  ),
                ),
              if (post.musicTitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: PressScale(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            MusicPageScreen(musicTitle: post.musicTitle!),
                      ),
                    ),
                    child: _tagPill(Icons.music_note_rounded, post.musicTitle!),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _action({
    required IconData icon,
    required Color color,
    String? label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: PressScale(
        onTap: onTap,
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 30,
              shadows: const [Shadow(color: Colors.black45, blurRadius: 8)],
            ),
            if (label != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppType.small,
                    fontWeight: AppType.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tagPill(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: Colors.black38,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: AppIconSize.sm),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: AppType.label,
              fontWeight: AppType.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Reels like button with optimistic UI (heart + count flip instantly on tap).
class _ReelLikeButton extends ConsumerStatefulWidget {
  const _ReelLikeButton({required this.post, required this.uid});
  final Post post;
  final String? uid;

  @override
  ConsumerState<_ReelLikeButton> createState() => _ReelLikeButtonState();
}

class _ReelLikeButtonState extends ConsumerState<_ReelLikeButton> {
  bool? _optimistic;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final serverLiked =
        ref.watch(isLikedProvider(post.postId)).valueOrNull ?? false;
    if (_optimistic != null && _optimistic == serverLiked) _optimistic = null;
    final liked = _optimistic ?? serverLiked;
    final count = post.likesCount +
        (_optimistic != null && _optimistic != serverLiked
            ? (_optimistic! ? 1 : -1)
            : 0);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: PressScale(
        onTap: () {
          final uid = widget.uid;
          if (uid == null) return;
          HapticFeedback.lightImpact();
          setState(() => _optimistic = !liked);
          ref.read(feedRepositoryProvider).toggleLike(post.postId, uid);
        },
        child: Column(
          children: [
            Icon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: liked ? AppColors.primary : Colors.white,
              size: 30,
              shadows: const [Shadow(color: Colors.black45, blurRadius: 8)],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                formatCount(count < 0 ? 0 : count),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppType.small,
                  fontWeight: AppType.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Caption with #hashtags tinted in the accent color.
class _CaptionText extends StatelessWidget {
  const _CaptionText({required this.caption});
  final String caption;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    for (final word in caption.split(RegExp(r'(\s+)'))) {
      if (word.isEmpty) continue;
      final isTag = word.startsWith('#') || word.startsWith('@');
      spans.add(
        TextSpan(
          text: '$word ',
          style: TextStyle(
            color: isTag ? AppColors.accent : Colors.white,
            fontWeight: isTag ? AppType.bold : AppType.regular,
          ),
        ),
      );
    }
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(fontSize: AppType.body, color: Colors.white),
        children: spans,
      ),
    );
  }
}

/// A rotating vinyl-style album disc for the attached track.
class _SpinningDisc extends StatefulWidget {
  const _SpinningDisc({required this.coverUrl, required this.spinning});
  final String? coverUrl;
  final bool spinning;

  @override
  State<_SpinningDisc> createState() => _SpinningDiscState();
}

class _SpinningDiscState extends State<_SpinningDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant _SpinningDisc old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.spinning && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _spin,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black,
          border: Border.all(color: Colors.white24, width: 3),
        ),
        clipBehavior: Clip.antiAlias,
        child: (widget.coverUrl ?? '').isNotEmpty
            ? CachedNetworkImage(imageUrl: widget.coverUrl!, fit: BoxFit.cover)
            : const Icon(
                Icons.music_note_rounded,
                color: Colors.white,
                size: 18,
              ),
      ),
    );
  }
}
