import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/post.dart';
import '../../../widgets/components/components.dart';
import 'widgets/post_card.dart';

/// A page-snapped post feed opened from a grid: one post per page as its own
/// independent card. Opens on the tapped post and swipes through the whole list
/// — up for the next post, down for the previous.
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
      // No inner scroll view: a nested same-axis scrollable would swallow the
      // drag and the page would never flip. Each page holds the post centred;
      // tall posts simply scroll the page itself.
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        itemCount: widget.posts.length,
        itemBuilder: (_, i) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            physics: const NeverScrollableScrollPhysics(),
            child: PostCard(post: widget.posts[i]),
          ),
        ),
      ),
    );
  }
}
