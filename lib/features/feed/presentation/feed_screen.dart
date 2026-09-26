import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants.dart';
import 'package:snapshot/core/i18n/i18n.dart';
import '../../../core/design/tokens.dart';
import '../../../widgets/components/components.dart';
import '../../../widgets/empty_view.dart';
import '../../../widgets/loading_view.dart';
import '../../../widgets/motion/motion.dart';
import '../../stories/presentation/widgets/story_ring.dart';
import '../providers/feed_providers.dart';
import 'widgets/post_card.dart';

/// Home feed with two custom segments: chronological "Đang theo dõi" and
/// "Yêu thích". The header (logo + tabs) collapses on scroll-down and snaps
/// back on scroll-up, and the story tray scrolls away with the posts, so
/// browsing photos gets the full screen height.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    // Rebuild so the segmented pill follows both taps and horizontal swipes.
    _tab.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            floating: true,
            snap: true,
            titleSpacing: AppSpacing.md,
            title: Text(
              'Snapshot',
              style: brandWordmark(context, size: 26),
            ),
            actions: [
              AppIconButton(
                icon: Icons.add_box_outlined,
                tooltip: tr('Đăng bài', 'Post'),
                onTap: () => context.push(Routes.createPost),
              ),
              AppIconButton(
                icon: Icons.mail_outline_rounded,
                tooltip: tr('Tin nhắn', 'Messages'),
                onTap: () => context.push(Routes.inbox),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: AppSegmentedTabs(
                index: _tab.index,
                labels: [
                  tr('Đang theo dõi', 'Following'),
                  tr('Yêu thích', 'Favorites'),
                ],
                onChanged: (i) => _tab.animateTo(i),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: const [
            _FeedList(kind: FeedKind.following, showStories: true),
            _FeedList(kind: FeedKind.favorites, showStories: false),
          ],
        ),
      ),
    );
  }
}

class _FeedList extends ConsumerStatefulWidget {
  const _FeedList({required this.kind, this.showStories = false});
  final FeedKind kind;
  final bool showStories;

  @override
  ConsumerState<_FeedList> createState() => _FeedListState();
}

class _FeedListState extends ConsumerState<_FeedList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// Post ids whose entrance animation has already played, so recycled rows
  /// don't re-animate as the user scrolls.
  final Set<String> _entered = {};

  /// Triggers pagination when the list nears its end. Uses scroll
  /// notifications instead of a controller so it cooperates with the
  /// NestedScrollView's coordinated scrolling.
  bool _onScroll(ScrollNotification n) {
    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 400) {
      ref.read(feedControllerProvider(widget.kind).notifier).loadMore();
    }
    return false;
  }

  Future<void> _refresh() =>
      ref.read(feedControllerProvider(widget.kind).notifier).refresh();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(feedControllerProvider(widget.kind));

    if (!state.initialized && state.isLoading) {
      return const LoadingView();
    }

    if (state.posts.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.layer2,
        onRefresh: _refresh,
        child: ListView(
          children: [
            if (widget.showStories) ...[
              const StoryRing(),
              const Divider(height: 1),
            ],
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: EmptyView(
                message: widget.kind == FeedKind.favorites
                    ? tr(
                        'Chưa có bài viết từ danh sách Yêu thích.\nThêm người vào Yêu thích từ menu bài viết.',
                        'No posts from your Favorites yet.\nAdd people to Favorites from the post menu.',
                      )
                    : tr(
                        'Chưa có bài viết.\nHãy theo dõi thêm người hoặc đăng bài.',
                        'No posts yet.\nFollow more people or create a post.',
                      ),
                icon: widget.kind == FeedKind.favorites
                    ? Icons.star_rounded
                    : Icons.dynamic_feed_rounded,
              ),
            ),
          ],
        ),
      );
    }

    // Leading story tray (Following only) scrolls away with the posts.
    final headerCount = widget.showStories ? 1 : 0;

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.layer2,
        onRefresh: _refresh,
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          itemCount: headerCount + state.posts.length + 1,
          itemBuilder: (_, i) {
            if (widget.showStories && i == 0) {
              return const Column(
                children: [
                  StoryRing(),
                  Divider(height: 1),
                  SizedBox(height: AppSpacing.xs),
                ],
              );
            }
            final postIndex = i - headerCount;
            if (postIndex == state.posts.length) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: state.hasMore
                      ? SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primary,
                          ),
                        )
                      : Text(
                          tr('Đã hết bài viết', 'No more posts'),
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: AppType.label,
                          ),
                        ),
                ),
              );
            }
            final post = state.posts[postIndex];
            final firstTime = _entered.add(post.postId);
            return MotionEntrance(
              index: postIndex,
              animate: firstTime,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: PostCard(post: post),
              ),
            );
          },
        ),
      ),
    );
  }
}
