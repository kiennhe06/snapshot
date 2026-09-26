import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:snapshot/core/design/tokens.dart';
import '../../../../core/utils/format.dart';
import '../../../../models/post.dart';
import '../../../../widgets/empty_view.dart';
import '../../../../widgets/motion/motion.dart';

/// A 3-column grid of post covers. Tapping a cell calls [onTap]; long-pressing
/// calls [onLongPress] (used on the owner's profile for pin/archive actions).
class PostGrid extends StatelessWidget {
  const PostGrid({
    super.key,
    required this.posts,
    required this.emptyMessage,
    this.emptyIcon = Icons.grid_on_rounded,
    this.onTap,
    this.onLongPress,
  });

  final List<Post> posts;
  final String emptyMessage;
  final IconData emptyIcon;
  final void Function(Post post)? onTap;
  final void Function(Post post)? onLongPress;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return EmptyView(message: emptyMessage, icon: emptyIcon);
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: _gridDelegate,
      itemCount: posts.length,
      itemBuilder: (_, i) => PostGridCell(
        post: posts[i],
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 3,
  crossAxisSpacing: 2,
  mainAxisSpacing: 2,
);

/// Neutral cover placeholder for a missing/failed post image — reads as
/// "no photo" (a soft card with a faint image glyph) instead of a broken-image
/// error box. Shared by the grid and the pinned strip.
Widget postCoverPlaceholder() => DecoratedBox(
  decoration: BoxDecoration(gradient: AppGradients.card),
  child: Center(
    child: Icon(
      Icons.image_outlined,
      size: 22,
      color: AppColors.textTertiary.withValues(alpha: 0.5),
    ),
  ),
);

/// Sliver variant of [PostGrid] for use inside a CustomScrollView /
/// NestedScrollView (so a profile's header can scroll away above it). Renders
/// an empty state as a fill-remaining sliver when there are no posts.
class SliverPostGrid extends StatelessWidget {
  const SliverPostGrid({
    super.key,
    required this.posts,
    required this.emptyMessage,
    this.emptyIcon = Icons.grid_on_rounded,
    this.onTap,
    this.onLongPress,
    this.entered,
  });

  final List<Post> posts;
  final String emptyMessage;
  final IconData emptyIcon;
  final void Function(Post post)? onTap;
  final void Function(Post post)? onLongPress;

  /// Ids of cells that have already animated in. Pass a set owned by the parent
  /// so the grid assembles once and recycled cells don't re-animate on scroll.
  final Set<String>? entered;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyView(message: emptyMessage, icon: emptyIcon),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.all(2),
      sliver: SliverGrid(
        gridDelegate: _gridDelegate,
        delegate: SliverChildBuilderDelegate((_, i) {
          final post = posts[i];
          final firstTime = entered?.add(post.postId) ?? true;
          return MotionEntrance(
            index: i,
            animate: firstTime,
            offset: 10,
            child: PostGridCell(
              post: post,
              onTap: onTap,
              onLongPress: onLongPress,
            ),
          );
        }, childCount: posts.length),
      ),
    );
  }
}

/// A single 3-column grid cell: cover image plus type/pin/like overlays.
class PostGridCell extends StatelessWidget {
  const PostGridCell({
    super.key,
    required this.post,
    this.onTap,
    this.onLongPress,
  });

  final Post post;
  final void Function(Post post)? onTap;
  final void Function(Post post)? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap == null ? null : () => onTap!(post),
      onLongPress: onLongPress == null ? null : () => onLongPress!(post),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (post.coverUrl.isEmpty)
            postCoverPlaceholder()
          else
            CachedNetworkImage(
              imageUrl: post.coverUrl,
              memCacheWidth: 400,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: AppColors.layer3),
              errorWidget: (_, _, _) => postCoverPlaceholder(),
            ),
          if (post.isVideo)
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          if (post.isCarousel)
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(
                Icons.collections_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          if (post.isPinned)
            const Positioned(
              top: 6,
              left: 6,
              child: Icon(
                Icons.push_pin_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          // Like-count overlay (bottom-left) with a readability scrim.
          if (!post.likesHidden && post.likesCount > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 12, 6, 5),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0x99000000), Color(0x00000000)],
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      formatCount(post.likesCount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 3),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A 3-column shimmer placeholder shown while a grid's posts load — reads as
/// "content is coming" instead of a lone spinner. Use as a sliver.
class SliverPostGridSkeleton extends StatelessWidget {
  const SliverPostGridSkeleton({super.key, this.count = 12});
  final int count;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(2),
      sliver: SliverToBoxAdapter(
        child: Shimmer(
          child: GridView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: _gridDelegate,
            itemCount: count,
            itemBuilder: (_, _) => const SkeletonBox(radius: 2),
          ),
        ),
      ),
    );
  }
}
