import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/story.dart';
import '../../auth/providers/auth_providers.dart';
import '../../feed/providers/feed_providers.dart';
import '../../interactions/providers/interaction_providers.dart';
import '../data/highlight_repository.dart';
import '../data/story_repository.dart';

final storyRepositoryProvider = Provider<StoryRepository>(
  (ref) => StoryRepository(),
);
final highlightRepositoryProvider = Provider<HighlightRepository>(
  (ref) => HighlightRepository(),
);

/// A per-author tray of active stories for the ring row.
class StoryTray {
  const StoryTray({required this.authorId, required this.stories});
  final String authorId;
  final List<Story> stories;
}

/// Story trays visible to the current user: own + followed authors, minus
/// blocked, honoring close-friends-only audience.
final storyTraysProvider = StreamProvider.autoDispose<List<StoryTray>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  final following = ref.watch(followingIdsProvider).valueOrNull ?? const [];
  final blocked = ref.watch(blockedIdsProvider).valueOrNull ?? const [];
  if (uid == null) return Stream.value(const []);

  return ref.watch(storyRepositoryProvider).watchActiveStories().map((stories) {
    bool visible(Story s) {
      if (blocked.contains(s.authorId)) return false;
      final audienceOk = s.authorId == uid || following.contains(s.authorId);
      if (!audienceOk) return false;
      if (s.closeFriendsOnly && s.authorId != uid) {
        return s.closeFriends.contains(uid);
      }
      return true;
    }

    final byAuthor = <String, List<Story>>{};
    for (final s in stories.where(visible)) {
      byAuthor.putIfAbsent(s.authorId, () => []).add(s);
    }
    final trays = byAuthor.entries
        .map((e) => StoryTray(authorId: e.key, stories: e.value))
        .toList();
    // Own tray first, then most-recent first.
    trays.sort((a, b) {
      if (a.authorId == uid) return -1;
      if (b.authorId == uid) return 1;
      return b.stories.last.createdAt.compareTo(a.stories.last.createdAt);
    });
    return trays;
  });
});

final myStoriesProvider = StreamProvider.autoDispose<List<Story>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(storyRepositoryProvider).watchUserStories(uid);
});

final storyViewersProvider = StreamProvider.autoDispose
    .family<List<String>, String>((ref, storyId) {
      return ref.watch(storyRepositoryProvider).watchViewers(storyId);
    });

final stickerAggregateProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, ({String storyId, String stickerId})>((
      ref,
      arg,
    ) {
      return ref
          .watch(storyRepositoryProvider)
          .watchAggregate(arg.storyId, arg.stickerId);
    });

final myStickerResponseProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, ({String storyId, String stickerId})>((
      ref,
      arg,
    ) {
      final uid = ref.watch(authStateProvider).valueOrNull?.uid;
      if (uid == null) return Stream.value(null);
      return ref
          .watch(storyRepositoryProvider)
          .watchMyResponse(arg.storyId, arg.stickerId, uid);
    });

final highlightsProvider = StreamProvider.autoDispose
    .family<List<Highlight>, String>((ref, uid) {
      return ref.watch(highlightRepositoryProvider).watchHighlights(uid);
    });
