import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/post.dart';
import '../../auth/providers/auth_providers.dart';
import '../../interactions/providers/interaction_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../data/feed_repository.dart';

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FeedRepository(),
);

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
  });

  final List<Post> posts;
  final bool isLoading;
  final bool hasMore;
  final DateTime? cursor;
  final bool initialized;

  FeedState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? hasMore,
    DateTime? cursor,
    bool? initialized,
  }) => FeedState(
    posts: posts ?? this.posts,
    isLoading: isLoading ?? this.isLoading,
    hasMore: hasMore ?? this.hasMore,
    cursor: cursor ?? this.cursor,
    initialized: initialized ?? this.initialized,
  );
}

final feedControllerProvider =
    NotifierProvider.family<FeedController, FeedState, FeedKind>(
      FeedController.new,
    );

class FeedController extends FamilyNotifier<FeedState, FeedKind> {
  late FeedKind _kind;

  @override
  FeedState build(FeedKind arg) {
    _kind = arg;
    // Kick off the first page after the notifier is constructed.
    Future.microtask(loadMore);
    return const FeedState();
  }

  FeedRepository get _repo => ref.read(feedRepositoryProvider);
  String? get _uid => ref.read(authStateProvider).valueOrNull?.uid;

  /// Keeps fetching raw pages until at least [want] new items pass the audience
  /// filter or there is nothing left — so a strict filter never yields a blank
  /// screen on the first page.
  Future<void> loadMore({int want = 6}) async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);

    var cursor = state.cursor;
    final collected = <Post>[];
    var hasMore = true;
    var guard = 0;
    while (collected.length < want && hasMore && guard < 6) {
      guard++;
      final page = await _repo.fetchPage(startAfter: cursor);
      collected.addAll(_applyAudience(page.posts));
      cursor = page.nextCursor;
      hasMore = page.hasMore;
    }

    state = state.copyWith(
      posts: [...state.posts, ...collected],
      cursor: cursor,
      hasMore: hasMore,
      isLoading: false,
      initialized: true,
    );
  }

  Future<void> refresh() async {
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
    return switch (_kind) {
      FeedKind.following =>
        posts
            .where((p) => p.authorId == uid || following.contains(p.authorId))
            .where(allowed)
            .where(notMuted)
            .toList(),
      FeedKind.favorites =>
        posts
            .where((p) => favorites.contains(p.authorId))
            .where(allowed)
            .toList(),
      FeedKind.explore =>
        posts
            .where((p) => p.authorId != uid && !following.contains(p.authorId))
            .where(allowed)
            .where(notMuted)
            .toList(),
    };
  }
}
