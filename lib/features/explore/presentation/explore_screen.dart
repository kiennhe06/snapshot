import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/core/i18n/i18n.dart';
import 'package:snapshot/core/utils/format.dart';
import 'package:snapshot/widgets/components/components.dart';
import '../../../core/constants.dart';
import '../../../models/app_user.dart';
import '../../../models/post.dart';
import '../../auth/providers/auth_providers.dart';
import '../../feed/providers/feed_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/search_providers.dart';
import 'search_screen.dart';


/// Explore: search, filter chips, trending topics, people suggestions and a
/// masonry of discovery content.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _scroll = ScrollController();
  final _dismissed = <String>{};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
        ref.read(feedControllerProvider(FeedKind.explore).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _openSearch() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const SearchScreen()));

  /// Top hashtags across the loaded explore posts (real, client-side).
  List<MapEntry<String, int>> _trending(List<Post> posts) {
    final counts = <String, int>{};
    for (final p in posts) {
      for (final h in p.hashtags) {
        if (h.trim().isEmpty) continue;
        counts[h] = (counts[h] ?? 0) + 1;
      }
    }
    final list = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final explore = ref.watch(feedControllerProvider(FeedKind.explore));
    final suggested = ref.watch(suggestedUsersProvider);
    final trending = _trending(explore.posts);

    return AppScaffold(
      topBar: AppTopBar(titleWidget: _searchBar()),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.layer2,
        onRefresh: () async {
          ref.invalidate(suggestedUsersProvider);
          await ref
              .read(feedControllerProvider(FeedKind.explore).notifier)
              .refresh();
        },
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(child: _filterChips()),
            if (trending.isNotEmpty)
              SliverToBoxAdapter(child: _trendingSection(trending)),
            SliverToBoxAdapter(
              child: suggested.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (users) {
                  final list = users
                      .where((u) => !_dismissed.contains(u.uid))
                      .toList();
                  if (list.isEmpty) return const SizedBox.shrink();
                  return _suggestionsSection(list);
                },
              ),
            ),
            SliverToBoxAdapter(
              child: _sectionHeader(
                tr('Khám phá nội dung', 'Discover'),
                Icons.auto_awesome_rounded,
              ),
            ),
            SliverToBoxAdapter(child: _masonry(explore.posts)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: explore.isLoading
                      ? CircularProgressIndicator(color: AppColors.primary)
                      : (explore.posts.isEmpty
                            ? Text(
                                tr(
                                  'Chưa có nội dung để khám phá.',
                                  'Nothing to explore yet.',
                                ),
                                style: TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: AppType.label,
                                ),
                              )
                            : const SizedBox.shrink()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Search + filters --------------------------------------------------------

  Widget _searchBar() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _openSearch,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.layer3,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: AppIconSize.md,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      tr(
                        'Tìm người dùng, hashtag, địa điểm',
                        'Search people, hashtags, places',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: AppType.body,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        AppIconButton(icon: Icons.qr_code_scanner_rounded, onTap: _openSearch),
      ],
    );
  }

  Widget _filterChips() {
    final filters = [
      (tr('Tất cả', 'All'), Icons.auto_awesome, true),
      (tr('Tài khoản', 'Accounts'), Icons.alternate_email_rounded, false),
      (tr('Thẻ bài viết', 'Tags'), Icons.tag_rounded, false),
      (tr('Địa điểm', 'Places'), Icons.place_outlined, false),
    ];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
        children: [
          for (final f in filters)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: PressScale(
                onTap: f.$3 ? null : _openSearch,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: f.$3
                        ? LinearGradient(
                            colors: [
                              AppColors.primaryBright,
                              AppColors.primary,
                            ],
                          )
                        : null,
                    color: f.$3 ? null : AppColors.layer3,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        f.$2,
                        size: AppIconSize.xs,
                        color: f.$3 ? AppColors.onPrimary : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        f.$1,
                        style: TextStyle(
                          color: f.$3 ? AppColors.onPrimary : AppColors.textSecondary,
                          fontSize: AppType.label,
                          fontWeight: AppType.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---- Trending ----------------------------------------------------------------

  Widget _trendingSection(List<MapEntry<String, int>> trending) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: AppIconSize.md,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                tr('Chủ đề thịnh hành', 'Trending'),
                style: AppText.h2,
              ),
              const Spacer(),
              Text(
                tr('Cập nhật liên tục', 'Live'),
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: AppType.small,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final t in trending)
              PressScale(
                onTap: _openSearch,
                child: Container(
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
                      Text(
                        '#${t.key}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: AppType.label,
                          fontWeight: AppType.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tr('${t.value} bài', '${t.value} posts'),
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: AppType.small,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ).paddedHorizontal(),
      ],
    );
  }

  // ---- Suggestions -------------------------------------------------------------

  Widget _suggestionsSection(List<AppUser> users) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.person_add_alt_1_rounded,
                size: AppIconSize.md,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                tr('Gợi ý cho bạn', 'Suggested for you'),
                style: AppText.h2,
              ),
              const Spacer(),
              PressScale(
                onTap: () {},
                child: Text(
                  tr('Xem tất cả', 'See all'),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: AppType.label,
                    fontWeight: AppType.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: users.length,
            itemBuilder: (_, i) => _SuggestionCard(
              user: users[i],
              onDismiss: () => setState(() => _dismissed.add(users[i].uid)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.md, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: AppText.h2,
          ),
        ],
      ),
    );
  }

  // ---- Masonry -----------------------------------------------------------------

  Widget _masonry(List<Post> posts) {
    // Split into two columns; vary tile heights for a staggered rhythm.
    final left = <Post>[];
    final right = <Post>[];
    for (var i = 0; i < posts.length; i++) {
      (i.isEven ? left : right).add(posts[i]);
    }
    Widget column(List<Post> col, int offset) => Expanded(
      child: Column(
        children: [
          for (var i = 0; i < col.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ExploreTile(
                post: col[i],
                ratio: _ratio((i + offset)),
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          column(left, 0),
          const SizedBox(width: AppSpacing.sm),
          column(right, 1),
        ],
      ),
    );
  }

  double _ratio(int i) {
    const ratios = [0.72, 1.0, 1.28, 0.86];
    return ratios[i % ratios.length];
  }
}

class _ExploreTile extends StatelessWidget {
  const _ExploreTile({required this.post, required this.ratio});
  final Post post;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: () =>
          context.push('${Routes.userProfile}/${post.authorId}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AspectRatio(
          aspectRatio: ratio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: post.coverUrl,
                memCacheWidth: 500,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: AppColors.layer3),
                errorWidget: (_, _, _) => Container(color: AppColors.layer3),
              ),
              // type badge
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: Icon(
                  post.isVideo
                      ? Icons.play_circle_fill_rounded
                      : (post.isCarousel
                            ? Icons.collections_rounded
                            : Icons.circle_outlined),
                  size: AppIconSize.md,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
              // bottom gradient + counts
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        size: AppIconSize.xs,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        formatCount(post.likesCount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppType.small,
                          fontWeight: AppType.bold,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        Icons.mode_comment_rounded,
                        size: AppIconSize.xs,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        formatCount(post.commentsCount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppType.small,
                          fontWeight: AppType.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends ConsumerWidget {
  const _SuggestionCard({required this.user, required this.onDismiss});
  final AppUser user;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageProvider = user.photoUrl != null
        ? CachedNetworkImageProvider(user.photoUrl!)
        : null;
    return Container(
      width: 168,
      margin: const EdgeInsets.all(AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppGradients.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topRight,
            child: PressScale(
              onTap: onDismiss,
              child: Icon(
                Icons.close_rounded,
                size: AppIconSize.sm,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => context.push('${Routes.userProfile}/${user.uid}'),
            child: AppAvatar(imageProvider: imageProvider, radius: 30),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  user.displayName.isNotEmpty
                      ? user.displayName
                      : user.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppType.body,
                    fontWeight: AppType.bold,
                  ),
                ),
              ),
              if (user.isVerified) ...[
                const SizedBox(width: 3),
                Icon(
                  Icons.verified_rounded,
                  size: AppIconSize.xs,
                  color: AppColors.accent,
                ),
              ],
            ],
          ),
          Text(
            '@${user.username}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: AppType.small,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: Text(
              user.bio.isNotEmpty
                  ? user.bio
                  : tr('Gợi ý cho bạn', 'Suggested for you'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppType.small,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: tr('Theo dõi', 'Follow'),
              height: 34,
              onPressed: () {
                final uid = ref.read(authStateProvider).valueOrNull?.uid;
                if (uid != null) {
                  ref
                      .read(followRepositoryProvider)
                      .follow(currentUid: uid, targetUid: user.uid);
                  showAppToast(
                    context,
                    tr(
                      'Đã theo dõi @${user.username}',
                      'Followed @${user.username}',
                    ),
                    type: AppToastType.success,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

extension _PadX on Widget {
  Widget paddedHorizontal() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    child: this,
  );
}
