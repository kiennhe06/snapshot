import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/post.dart';
import '../../../widgets/components/components.dart';
import 'widgets/post_card.dart';

/// A scrollable post feed opened from a grid: the tapped post sits at the top
/// and the viewer scrolls down through the rest (like Instagram's post view),
/// instead of seeing a single post in a sheet.
class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({
    super.key,
    required this.posts,
    this.initialIndex = 0,
    this.title,
  });

  final List<Post> posts;
  final int initialIndex;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final start = initialIndex.clamp(0, posts.isEmpty ? 0 : posts.length - 1);
    final visible = posts.isEmpty ? const <Post>[] : posts.sublist(start);

    return AppScaffold(
      topBar: AppTopBar(
        title: title ?? tr('Bài viết', 'Posts'),
        showBack: true,
      ),
      // Each post floats as its own card with a clear gutter between them, so
      // scrolling reads as moving from one post to the next rather than one
      // continuous sheet.
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xxl),
        itemBuilder: (_, i) => PostCard(post: visible[i]),
      ),
    );
  }
}
