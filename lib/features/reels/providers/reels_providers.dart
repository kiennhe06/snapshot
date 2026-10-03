import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/post.dart';
import '../../auth/providers/auth_providers.dart';
import '../../feed/data/feed_repository.dart';
import '../../feed/data/interest_repository.dart';
import '../../feed/providers/feed_providers.dart';
import '../../interactions/providers/interaction_providers.dart';

/// Whether the app's bottom nav is shown while the Reels tab is active.
/// Reels plays immersive (nav hidden) by default; tapping a reel reveals the
/// nav so the viewer can switch tabs, and tapping again hides it.
class ReelsChrome extends Notifier<bool> {
  @override
  bool build() => false;

  void show() => state = true;
  void hide() => state = false;
}

final reelsChromeProvider = NotifierProvider<ReelsChrome, bool>(
  ReelsChrome.new,
);

/// Paginated vertical reels feed state (video posts, newest first).
class ReelsState {
  const ReelsState({
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

  ReelsState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? hasMore,
    DateTime? cursor,
    bool? initialized,
  }) => ReelsState(
    posts: posts ?? this.posts,
    isLoading: isLoading ?? this.isLoading,
    hasMore: hasMore ?? this.hasMore,
    cursor: cursor ?? this.cursor,
    initialized: initialized ?? this.initialized,
  );
}

final reelsControllerProvider = NotifierProvider<ReelsController, ReelsState>(
  ReelsController.new,
);

/// Which slice of reels to show.
enum ReelsTab { forYou, following }

class ReelsController extends Notifier<ReelsState> {
  ReelsTab _tab = ReelsTab.forYou;
  ReelsTab get tab => _tab;

  // "For you" ranked pagination: candidates are fetched in batches, each batch
  // is ranked by interest and appended to this buffer, then served a page at a
  // time — so already-shown reels never reorder.
  final List<Post> _forYouBuffer = [];
  final Set<String> _seen = {};
  InterestProfile? _profile;
  bool _poolHasMore = true;

  @override
  ReelsState build() {
    Future.microtask(loadMore);
    return const ReelsState();
  }

  FeedRepository get _repo => ref.read(feedRepositoryProvider);

  /// Switches the active tab and reloads from scratch.
  Future<void> setTab(ReelsTab tab) async {
    if (tab == _tab) return;
    _tab = tab;
    await refresh();
  }

  Future<void> loadMore({int want = 4}) async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    final blocked = ref.read(blockedIdsProvider).valueOrNull ?? const [];

    // "For you": ranked pagination. Refill the ranked buffer from a fresh
    // candidate batch when it runs low, then serve the next page from it.
    if (_tab == ReelsTab.forYou) {
      if (_forYouBuffer.length < want && _poolHasMore) {
        _profile ??= uid == null
            ? const InterestProfile()
            : await ref.read(interestRepositoryProvider).get(uid);
        final batch = <Post>[];
        var cursor = state.cursor;
        var hasMore = true;
        var guard = 0;
        while (batch.length < 30 && hasMore && guard < 6) {
          guard++;
          final page = await _repo.fetchPage(startAfter: cursor, pageSize: 20);
          batch.addAll(
            page.posts.where(
              (p) =>
                  p.isVideo &&
                  p.authorId != uid &&
                  !blocked.contains(p.authorId) &&
                  _seen.add(p.postId),
            ),
          );
          cursor = page.nextCursor;
          hasMore = page.hasMore;
        }
        _forYouBuffer.addAll(rankByInterest(batch, _profile!));
        _poolHasMore = hasMore;
        state = state.copyWith(cursor: cursor);
      }
      final take = _forYouBuffer.take(want).toList();
      _forYouBuffer.removeRange(0, take.length);
      state = state.copyWith(
        posts: [...state.posts, ...take],
        hasMore: _forYouBuffer.isNotEmpty || _poolHasMore,
        isLoading: false,
        initialized: true,
      );
      return;
    }

    // "Following": chronological, paginated.
    final following = ref.read(followingIdsProvider).valueOrNull ?? const [];
    var cursor = state.cursor;
    final collected = <Post>[];
    var hasMore = true;
    var guard = 0;
    while (collected.length < want && hasMore && guard < 8) {
      guard++;
      final page = await _repo.fetchPage(startAfter: cursor, pageSize: 12);
      collected.addAll(
        page.posts.where(
          (p) =>
              p.isVideo &&
              p.authorId != uid &&
              !blocked.contains(p.authorId) &&
              following.contains(p.authorId),
        ),
      );
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
    _forYouBuffer.clear();
    _seen.clear();
    _profile = null;
    _poolHasMore = true;
    state = const ReelsState();
    await loadMore();
  }
}

/// Reels that use a given music title.
final musicReelsProvider = StreamProvider.autoDispose
    .family<List<Post>, String>((ref, music) {
      return ref.watch(feedRepositoryProvider).watchPostsByMusic(music);
    });
