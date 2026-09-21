import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:snapshot/core/design/tokens.dart';
import '../../../../models/post.dart';
import '../../../../widgets/empty_view.dart';

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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: posts.length,
      itemBuilder: (_, i) {
        final post = posts[i];
        return GestureDetector(
          onTap: onTap == null ? null : () => onTap!(post),
          onLongPress: onLongPress == null ? null : () => onLongPress!(post),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: post.coverUrl,
                memCacheWidth: 400,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: AppColors.layer3),
                errorWidget: (_, _, _) => Container(
                  color: AppColors.layer3,
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: AppColors.textTertiary,
                  ),
                ),
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
                          _fmtCount(post.likesCount),
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
      },
    );
  }
}

String _fmtCount(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) {
    return '${(n / 1000).toStringAsFixed(n % 1000 >= 100 ? 1 : 0)}K';
  }
  return '${(n / 1000000).toStringAsFixed(1)}M';
}
