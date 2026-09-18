import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tìm người dùng, hashtag, địa điểm',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
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
                        padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
                        child: Text(
                          'Gợi ý theo dõi',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      SizedBox(
                        height: 180,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
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
            SliverPadding(
              padding: const EdgeInsets.all(2),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                delegate: SliverChildBuilderDelegate((_, i) {
                  final post = explore.posts[i];
                  return GestureDetector(
                    onTap: () =>
                        context.push('${Routes.userProfile}/${post.authorId}'),
                    child: CachedNetworkImage(
                      imageUrl: post.coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: Colors.black12),
                      errorWidget: (_, _, _) => const Icon(Icons.broken_image),
                    ),
                  );
                }, childCount: explore.posts.length),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: explore.isLoading
                      ? const CircularProgressIndicator()
                      : (explore.posts.isEmpty
                            ? const Text('Chưa có nội dung để khám phá.')
                            : const SizedBox.shrink()),
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
    return Container(
      width: 140,
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => context.push('${Routes.userProfile}/${user.uid}'),
            child: CircleAvatar(
              radius: 30,
              backgroundImage: user.photoUrl != null
                  ? CachedNetworkImageProvider(user.photoUrl!)
                  : null,
              child: user.photoUrl == null ? const Icon(Icons.person) : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            user.username.isNotEmpty ? '@${user.username}' : user.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(32),
              padding: EdgeInsets.zero,
            ),
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
            child: const Text('Theo dõi'),
          ),
        ],
      ),
    );
  }
}
