import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants.dart';
import 'package:snapshot/core/i18n/i18n.dart';
import '../../../core/design/tokens.dart';
import '../../../widgets/components/components.dart';
import '../../../widgets/empty_view.dart';
import '../../../widgets/error_view.dart';
import '../../../widgets/motion/motion.dart';
import '../../stories/presentation/widgets/story_ring.dart';
import '../providers/feed_providers.dart';
import 'widgets/feed_skeleton.dart';
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
          children: [
            const _FeedList(kind: FeedKind.following, showStories: true),
            _FeedList(
              kind: FeedKind.favorites,
              showStories: false,
              // From the Favorites empty state, jump to Following where posts
              // can be favorited from the ··· menu.
              onBrowseFollowing: () => _tab.animateTo(0),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedList extends ConsumerStatefulWidget {
  const _FeedList({
    required this.kind,
    this.showStories = false,
    this.onBrowseFollowing,
  });
  final FeedKind kind;
  final bool showStories;

  /// Favorites-only: switch to the Following tab from the empty state CTA.
  final VoidCallback? onBrowseFollowing;

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
      return const FeedSkeleton();
    }

    if (state.error != null && state.posts.isEmpty) {
      return ErrorView(
        message: tr(
          'Không tải được bảng tin. Kéo để thử lại.',
          'Could not load the feed. Pull to retry.',
        ),
        onRetry: _refresh,
      );
    }

    if (state.posts.isEmpty) {
      final isFavorites = widget.kind == FeedKind.favorites;
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
              height: MediaQuery.of(context).size.height * 0.72,
              child: isFavorites
                  ? _FavoritesEmpty(onBrowse: widget.onBrowseFollowing)
                  : EmptyView(
                      message: tr(
                        'Chưa có bài viết.\nHãy theo dõi thêm người hoặc đăng bài.',
                        'No posts yet.\nFollow more people or create a post.',
                      ),
                      icon: Icons.dynamic_feed_rounded,
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
                          style: AppText.label.copyWith(color: AppColors.textTertiary),
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

/// A warm, illustrated empty state for the Favorites tab: a star-badged
/// cluster, a friendly title + subtitle, a concrete "how to favorite" hint and
/// a CTA that jumps to the Following feed where posts can be favorited.
class _FavoritesEmpty extends StatelessWidget {
  const _FavoritesEmpty({this.onBrowse});
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: AppSpacing.xl),
            const _FavoritesArt(),
            const SizedBox(height: AppSpacing.xl),
            Text(
              tr('Chưa có ai trong Yêu thích', 'No favorites yet'),
              textAlign: TextAlign.center,
              style: AppText.h2,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              tr(
                'Thêm bạn thân vào Yêu thích để bài của họ luôn hiện ở đây đầu tiên.',
                'Add close friends to Favorites so their posts always show up here first.',
              ),
              textAlign: TextAlign.center,
              style: AppText.h3.copyWith(
                color: AppColors.textSecondary,
                fontWeight: AppType.regular,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _FavoritesHint(),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: tr('Xem bài đang theo dõi', 'Browse Following'),
              icon: Icons.dynamic_feed_rounded,
              variant: AppButtonVariant.secondary,
              fullWidth: false,
              onPressed: onBrowse,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

/// The illustration: a glowing star card flanked by two "favourited person"
/// chips and a few sparkles — drawn entirely with tokens so it follows the
/// active skin.
class _FavoritesArt extends StatelessWidget {
  const _FavoritesArt();

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.primary;
    return SizedBox(
      width: 230,
      height: 164,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft glow halo.
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [accent.withValues(alpha: 0.18), Colors.transparent],
                stops: const [0, 0.72],
              ),
            ),
          ),
          // Flanking favourited-person chips.
          Positioned(
            left: 8,
            top: 30,
            child: Transform.rotate(
              angle: -0.18,
              child: const _MiniFav(),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 24,
            child: Transform.rotate(
              angle: 0.16,
              child: const _MiniFav(),
            ),
          ),
          // Sparkles.
          Positioned(
            right: 54,
            top: 16,
            child: Icon(
              Icons.auto_awesome,
              size: 18,
              color: accent.withValues(alpha: 0.65),
            ),
          ),
          Positioned(
            left: 56,
            bottom: 18,
            child: Icon(
              Icons.auto_awesome,
              size: 13,
              color: accent.withValues(alpha: 0.45),
            ),
          ),
          // The hero star card.
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: AppGradients.card,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.24),
                  blurRadius: 26,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Icon(Icons.star_rounded, size: 48, color: accent),
          ),
        ],
      ),
    );
  }
}

/// A small circular avatar placeholder with a star badge — a "favourited
/// friend" token used to decorate the empty state.
class _MiniFav extends StatelessWidget {
  const _MiniFav();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.card,
              border: Border.all(color: AppColors.borderSubtle),
              boxShadow: AppShadows.soft,
            ),
            child: Icon(
              Icons.person_rounded,
              size: 24,
              color: AppColors.textTertiary,
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                border: Border.all(color: AppColors.layer1, width: 2),
              ),
              child: const Icon(Icons.star_rounded, size: 11, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// A concrete how-to pill: "···  →  ⭐ Add to Favorites".
class _FavoritesHint extends StatelessWidget {
  const _FavoritesHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.layer3,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.star_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              tr('Thêm vào Yêu thích', 'Add to Favorites'),
              style: AppText.label.copyWith(
                color: AppColors.textSecondary,
                fontWeight: AppType.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
