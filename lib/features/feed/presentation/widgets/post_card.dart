import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants.dart';
import '../../../../models/post.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../providers/feed_providers.dart';

/// A single feed post: author header, media carousel, like/comment actions and
/// caption. Images are cached ([CachedNetworkImage]) and carry alt text as a
/// semantics label for screen readers.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: GestureDetector(
            onTap: () => context.push('${Routes.userProfile}/${post.authorId}'),
            child: CircleAvatar(
              backgroundImage: author?.photoUrl != null
                  ? CachedNetworkImageProvider(author!.photoUrl!)
                  : null,
              child: author?.photoUrl == null ? const Icon(Icons.person) : null,
            ),
          ),
          title: Text(
            author?.username.isNotEmpty == true
                ? author!.username
                : (author?.displayName ?? '...'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: post.location != null ? Text(post.location!) : null,
          trailing: IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () => _postMenu(context, post),
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
                      color: Colors.black,
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          color: Colors.white,
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
                      placeholder: (_, _) => Container(color: Colors.black12),
                      errorWidget: (_, _, _) => const Icon(Icons.broken_image),
                    ),
                  );
                },
              ),
              if (post.media.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
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
                          color: active ? Colors.white : Colors.white54,
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),

        // Actions
        Row(
          children: [
            IconButton(
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Theme.of(context).colorScheme.primary : null,
              ),
              tooltip: isLiked ? 'Bỏ thích' : 'Thích',
              onPressed: () {
                final uid = ref.read(authStateProvider).valueOrNull?.uid;
                if (uid != null) {
                  ref.read(feedRepositoryProvider).toggleLike(post.postId, uid);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.mode_comment_outlined),
              onPressed: post.commentsDisabled
                  ? null
                  : () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Bình luận sẽ có ở giai đoạn sau.'),
                      ),
                    ),
            ),
          ],
        ),

        // Likes + caption
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!post.likesHidden)
                Text(
                  '${post.likesCount} lượt thích',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              if (post.caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text:
                              '${author?.username.isNotEmpty == true ? author!.username : ''} ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: post.caption),
                      ],
                    ),
                  ),
                ),
              if (!post.commentsDisabled && post.commentsCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Xem tất cả ${post.commentsCount} bình luận',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  DateFormat('dd/MM/yyyy HH:mm', 'vi').format(post.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
              leading: Icon(isFav ? Icons.star : Icons.star_border),
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
              leading: const Icon(Icons.person_outline),
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
