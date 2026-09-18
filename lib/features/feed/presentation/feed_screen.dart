import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../widgets/empty_view.dart';
import '../../../widgets/loading_view.dart';
import '../providers/feed_providers.dart';
import 'widgets/post_card.dart';

/// Home feed with two tabs: chronological "Đang theo dõi" and "Yêu thích".
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Snapshot'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_box_outlined),
              tooltip: 'Đăng bài',
              onPressed: () => context.push(Routes.createPost),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Đang theo dõi'),
              Tab(text: 'Yêu thích'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FeedList(kind: FeedKind.following),
            _FeedList(kind: FeedKind.favorites),
          ],
        ),
      ),
    );
  }
}

class _FeedList extends ConsumerStatefulWidget {
  const _FeedList({required this.kind});
  final FeedKind kind;

  @override
  ConsumerState<_FeedList> createState() => _FeedListState();
}

class _FeedListState extends ConsumerState<_FeedList>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      ref.read(feedControllerProvider(widget.kind).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(feedControllerProvider(widget.kind));

    if (!state.initialized && state.isLoading) {
      return const LoadingView();
    }
    if (state.posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: () =>
            ref.read(feedControllerProvider(widget.kind).notifier).refresh(),
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: EmptyView(
                message: widget.kind == FeedKind.favorites
                    ? 'Chưa có bài viết từ danh sách Yêu thích.\nThêm người vào Yêu thích từ menu bài viết.'
                    : 'Chưa có bài viết. Hãy theo dõi thêm người hoặc đăng bài.',
                icon: Icons.dynamic_feed,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(feedControllerProvider(widget.kind).notifier).refresh(),
      child: ListView.builder(
        controller: _scroll,
        itemCount: state.posts.length + 1,
        itemBuilder: (_, i) {
          if (i == state.posts.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: state.hasMore
                    ? const CircularProgressIndicator()
                    : const Text('Đã hết bài viết'),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PostCard(post: state.posts[i]),
          );
        },
      ),
    );
  }
}
