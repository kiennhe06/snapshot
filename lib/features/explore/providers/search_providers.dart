import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../../models/post.dart';
import '../../auth/providers/auth_providers.dart';
import '../../feed/providers/feed_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../data/search_repository.dart';

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(),
);

/// Follow suggestions for the current user, personalized by the learned
/// interest profile: accounts whose content you engage with but don't yet
/// follow are surfaced first, then popular accounts re-ranked by that same
/// affinity.
final suggestedUsersProvider = FutureProvider.autoDispose<List<AppUser>>((
  ref,
) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const [];
  final following = ref.watch(followingIdsProvider).valueOrNull ?? const [];
  final followingSet = following.toSet();

  final base = await ref
      .watch(searchRepositoryProvider)
      .suggestedUsers(currentUid: uid, followingIds: following);
  final profile = await ref.watch(interestRepositoryProvider).get(uid);
  if (profile.authors.isEmpty) return base;

  final baseIds = base.map((u) => u.uid).toSet();

  // Accounts you interact with (watched/liked their posts) but haven't
  // followed — the strongest, most personal suggestions.
  final engaged =
      profile.authors.entries
          .where(
            (e) =>
                e.value > 0 &&
                e.key != uid &&
                !followingSet.contains(e.key) &&
                !baseIds.contains(e.key),
          )
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

  final userRepo = ref.watch(userRepositoryProvider);
  final prepend = <AppUser>[];
  for (final e in engaged.take(6)) {
    final u = await userRepo.getUser(e.key);
    if (u != null) prepend.add(u);
  }

  // Re-rank the popular base by the same affinity.
  base.sort(
    (a, b) =>
        (profile.authors[b.uid] ?? 0).compareTo(profile.authors[a.uid] ?? 0),
  );

  return [...prepend, ...base];
});

final userSearchProvider = FutureProvider.autoDispose
    .family<List<AppUser>, String>((ref, query) {
      return ref.watch(searchRepositoryProvider).searchUsers(query);
    });

final hashtagSearchProvider = FutureProvider.autoDispose
    .family<List<Post>, String>((ref, query) {
      return ref.watch(searchRepositoryProvider).searchHashtag(query);
    });

final locationSearchProvider = FutureProvider.autoDispose
    .family<List<Post>, String>((ref, query) {
      return ref.watch(searchRepositoryProvider).searchLocation(query);
    });
