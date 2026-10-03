import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/post.dart';
import '../../auth/providers/auth_providers.dart';
import '../../interactions/providers/interaction_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../data/feed_repository.dart';
import '../data/interest_repository.dart';

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FeedRepository(),
);

/// Per-user interest profile store (behaviour tracking + "For you" ranking).
final interestRepositoryProvider = Provider<InterestRepository>(
  (ref) => InterestRepository(),
);

/// The current user's learned interest profile, loaded once per view. Used to
/// rank discovery surfaces (Explore grid, For-you reels).
final interestProfileProvider = FutureProvider.autoDispose<InterestProfile>((
  ref,
) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const InterestProfile();
  return ref.read(interestRepositoryProvider).get(uid);
});

/// Top hashtags across recent posts (real, counted client-side). Used for the
/// composer's hashtag suggestions.
final trendingHashtagsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final page = await ref.watch(feedRepositoryProvider).fetchPage(pageSize: 50);
  final counts = <String, int>{};
  for (final p in page.posts) {
    for (final h in p.hashtags) {
      if (h.trim().isEmpty) continue;
      counts[h] = (counts[h] ?? 0) + 1;
    }
  }
  final list = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return list.take(12).map((e) => e.key).toList();
});

/// Uids the current user follows.
final followingIdsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(followRepositoryProvider).watchFollowingIds(uid);
});

/// Uids the current user marked as favorites (close friends).
final favoriteIdsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(feedRepositoryProvider).watchFavoriteIds(uid);
});

/// Whether the current user has liked a given post.
final isLikedProvider = StreamProvider.autoDispose.family<bool, String>((
  ref,
  postId,
) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(false);
  return ref.watch(feedRepositoryProvider).watchIsLiked(postId, uid);
});

/// Which audience a feed shows.
enum FeedKind { following, favorites, explore }

/// Paginated feed state.
class FeedState {
  const FeedState({
    this.posts = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.cursor,
    this.initialized = false,
    this.error,
  });

  final List<Post> posts;
  final bool isLoading;
  final bool hasMore;
  final DateTime? cursor;
  final bool initialized;

  /// Last load failure (network etc.). Cleared on every state transition, so it
  /// only lives between a failed fetch and the next action (retry).
  final Object? error;

  FeedState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? hasMore,
    DateTime? cursor,
    bool? initialized,
    Object? error,
  }) => FeedState(
    posts: posts ?? this.posts,
    isLoading: isLoading ?? this.isLoading,
    hasMore: hasMore ?? this.hasMore,
    cursor: cursor ?? this.cursor,
    initialized: initialized ?? this.initialized,
    error: error,
  );
}

final feedControllerProvider =
    NotifierProvider.family<FeedController, FeedState, FeedKind>(
      FeedController.new,
    );

class FeedController extends FamilyNotifier<FeedState, FeedKind> {
  late FeedKind _kind;

  /// Every post fetched this session, before the audience filter — kept so we
  /// can re-filter reactively when favorite/follow/mute/block lists change.
  final List<Post> _raw = [];

  @override
  FeedState build(FeedKind arg) {
    _kind = arg;
    // Re-filter immediately when any audience list changes, so favoriting,
    // following, muting or blocking takes effect without waiting for a reload.
    ref.listen(favoriteIdsProvider, (_, _) => _reapplyAudience());
    ref.listen(followingIdsProvider, (_, _) => _reapplyAudience());
    ref.listen(blockedIdsProvider, (_, _) => _reapplyAudience());
    ref.listen(mutedIdsProvider, (_, _) => _reapplyAudience());
    // Kick off the first page after the notifier is constructed.
    Future.microtask(loadMore);
    return const FeedState();
  }

  /// Recomputes the visible posts from the raw pool so a fresh
  /// favorite/follow/mute/block is reflected right away.
  void _reapplyAudience() {
    if (_raw.isEmpty) return;
    state = state.copyWith(posts: _applyAudience(_raw));
  }

  FeedRepository get _repo => ref.read(feedRepositoryProvider);
  String? get _uid => ref.read(authStateProvider).valueOrNull?.uid;

  /// Keeps fetching raw pages until at least [want] new items pass the audience
  /// filter or there is nothing left — so a strict filter never yields a blank
  /// screen on the first page.
  Future<void> loadMore({int want = 6}) async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true); // also clears any prior error

    try {
      var cursor = state.cursor;
      var hasMore = true;
      var guard = 0;
      final before = _applyAudience(_raw).length;
      // Keep paging until at least [want] NEW posts pass the audience filter.
      while (_applyAudience(_raw).length - before < want &&
          hasMore &&
          guard < 6) {
        guard++;
        final page = await _repo.fetchPage(startAfter: cursor);
        _raw.addAll(page.posts);
        cursor = page.nextCursor;
        hasMore = page.hasMore;
      }

      state = state.copyWith(
        posts: _applyAudience(_raw),
        cursor: cursor,
        hasMore: hasMore,
        isLoading: false,
        initialized: true,
      );
    } catch (e) {
      // Never leave the feed stuck spinning: surface the error + let it retry.
      state = state.copyWith(isLoading: false, initialized: true, error: e);
    }
  }

  Future<void> refresh() async {
    _raw.clear();
    state = const FeedState();
    await loadMore();
  }

  List<Post> _applyAudience(List<Post> posts) {
    final uid = _uid;
    final following = ref.read(followingIdsProvider).valueOrNull ?? const [];
    final favorites = ref.read(favoriteIdsProvider).valueOrNull ?? const [];
    final blocked = ref.read(blockedIdsProvider).valueOrNull ?? const [];
    final muted = ref.read(mutedIdsProvider).valueOrNull ?? const [];
    // Blocked authors are hidden everywhere; muted authors are hidden from the
    // home feeds (but still reachable via their profile).
    bool allowed(Post p) => !blocked.contains(p.authorId);
    bool notMuted(Post p) => !muted.contains(p.authorId);
    // Followers-only posts are visible only to the author and their followers.
    bool visible(Post p) =>
        !p.isFollowersOnly ||
        p.authorId == uid ||
        following.contains(p.authorId);
    return switch (_kind) {
      FeedKind.following =>
        posts
            .where((p) => p.authorId == uid || following.contains(p.authorId))
            .where(allowed)
            .where(notMuted)
            .where(visible)
            .toList(),
      FeedKind.favorites =>
        posts
            .where((p) => favorites.contains(p.authorId))
            .where(allowed)
            .where(visible)
            .toList(),
      FeedKind.explore =>
        posts
            .where((p) => p.authorId != uid && !following.contains(p.authorId))
            .where(allowed)
            .where(notMuted)
            .where(visible)
            .toList(),
    };
  }
}
