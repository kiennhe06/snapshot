import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/post.dart';
import '../../../widgets/components/components.dart';
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
            Text(
              'Reels',
              style: TextStyle(
                color: Colors.white,
                fontSize: AppType.title,
                fontWeight: AppType.heavy,
                shadows: const [Shadow(color: Colors.black45, blurRadius: 8)],
              ),
            ),
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
    final isLiked =
        ref.watch(isLikedProvider(post.postId)).valueOrNull ?? false;
    final isSaved =
        ref.watch(isSavedProvider(post.postId)).valueOrNull ?? false;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video
        if (post.media.isNotEmpty)
          AppVideo(url: post.media.first.url, active: active, muted: muted)
        else
          const ColoredBox(color: Colors.black),

        // Right actions
        Positioned(
          right: AppSpacing.md,
          bottom: 96,
          child: Column(
            children: [
              _action(
                icon: isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isLiked ? AppColors.primary : Colors.white,
                label: '${post.likesCount}',
                onTap: () {
                  if (uid != null) {
                    ref
                        .read(feedRepositoryProvider)
                        .toggleLike(post.postId, uid);
                  }
                },
              ),
              _action(
                icon: Icons.mode_comment_outlined,
                color: Colors.white,
                label: '${post.commentsCount}',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CommentsScreen(post: post)),
                ),
              ),
              _action(
                icon: Icons.send_outlined,
                color: Colors.white,
                onTap: () => Share.share(
                  'Snapshot reel: snapshot://user/${post.authorId}',
                ),
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
                  Text(
                    author?.username.isNotEmpty == true
                        ? author!.username
                        : (author?.displayName ?? ''),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: AppType.bold,
                      fontSize: AppType.subhead,
                    ),
                  ),
                ],
              ),
              if (post.caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    post.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: AppType.body,
                    ),
                  ),
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
