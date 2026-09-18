import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/widgets/components/components.dart';
import '../../../core/constants.dart';
import '../../../models/app_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../../feed/providers/feed_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/search_providers.dart';
import 'search_screen.dart';

/// Explore: search entry, follow suggestions, and a paginated grid of posts
/// from accounts the user does not follow yet.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _scroll = ScrollController();

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

  @override
  Widget build(BuildContext context) {
    final explore = ref.watch(feedControllerProvider(FeedKind.explore));
    final suggested = ref.watch(suggestedUsersProvider);

    return AppScaffold(
      topBar: AppTopBar(titleWidget: _searchEntry(context)),
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
            // Suggested users
            SliverToBoxAdapter(
              child: suggested.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (users) {
                  if (users.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.xs,
                        ),
                        child: Text(
                          'Gợi ý theo dõi',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: AppType.headline,
                            fontWeight: AppType.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 188,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          itemCount: users.length,
                          itemBuilder: (_, i) =>
                              _SuggestionCard(user: users[i]),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // Explore grid
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  'Khám phá',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppType.headline,
                    fontWeight: AppType.bold,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                ),
                delegate: SliverChildBuilderDelegate((_, i) {
                  final post = explore.posts[i];
                  return GestureDetector(
                    onTap: () =>
                        context.push('${Routes.userProfile}/${post.authorId}'),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: CachedNetworkImage(
                        imageUrl: post.coverUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: AppColors.layer3),
                        errorWidget: (_, _, _) => Container(
                          color: AppColors.layer3,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_rounded,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  );
                }, childCount: explore.posts.length),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: explore.isLoading
                      ? const CircularProgressIndicator(
                          color: AppColors.primary,
                        )
                      : (explore.posts.isEmpty
                            ? const Text(
                                'Chưa có nội dung để khám phá.',
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

  /// Soft rounded pill that opens the full [SearchScreen] on tap.
  Widget _searchEntry(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.layer3,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: AppIconSize.md,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text(
                'Tìm người dùng, hashtag, địa điểm',
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
    );
  }
}

class _SuggestionCard extends ConsumerWidget {
  const _SuggestionCard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageProvider = user.photoUrl != null
        ? CachedNetworkImageProvider(user.photoUrl!)
        : null;
    return AppCard(
      margin: const EdgeInsets.all(AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SizedBox(
        width: 132,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => context.push('${Routes.userProfile}/${user.uid}'),
              child: AppAvatar(imageProvider: imageProvider, radius: 30),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              user.username.isNotEmpty ? '@${user.username}' : user.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppType.body,
                fontWeight: AppType.medium,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Theo dõi',
              variant: AppButtonVariant.secondary,
              fullWidth: false,
              height: 36,
              onPressed: () {
                final uid = ref.read(authStateProvider).valueOrNull?.uid;
                if (uid != null) {
                  ref
                      .read(followRepositoryProvider)
                      .follow(currentUid: uid, targetUid: user.uid);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã theo dõi @${user.username}')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
