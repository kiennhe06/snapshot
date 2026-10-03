import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/post.dart';
import '../../../widgets/components/components.dart';
import 'widgets/post_card.dart';

/// A page-snapped post feed opened from a grid: one post per page as its own
/// independent card. Opens on the tapped post and swipes both ways — up for the
/// next post, down for the previous — through the whole list, like Instagram's
/// post view. Tall posts scroll inside their own page.
class PostDetailScreen extends StatefulWidget {
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
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    final last = widget.posts.isEmpty ? 0 : widget.posts.length - 1;
    _controller = PageController(
      initialPage: widget.initialIndex.clamp(0, last),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: AppTopBar(
        title: widget.title ?? tr('Bài viết', 'Posts'),
        showBack: true,
      ),
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        itemCount: widget.posts.length,
        itemBuilder: (_, i) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: PostCard(post: widget.posts[i]),
            ),
          ),
        ),
      ),
    );
  }
}
