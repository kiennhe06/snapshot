import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/post.dart';
import '../../auth/providers/auth_providers.dart';
import '../../feed/data/feed_repository.dart';
import '../../feed/providers/feed_providers.dart';
import '../../interactions/providers/interaction_providers.dart';

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
    final following = _tab == ReelsTab.following
        ? (ref.read(followingIdsProvider).valueOrNull ?? const [])
        : const <String>[];

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
              (_tab == ReelsTab.forYou || following.contains(p.authorId)),
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
    state = const ReelsState();
    await loadMore();
  }
}

/// Reels that use a given music title.
final musicReelsProvider = StreamProvider.autoDispose
    .family<List<Post>, String>((ref, music) {
      return ref.watch(feedRepositoryProvider).watchPostsByMusic(music);
    });
