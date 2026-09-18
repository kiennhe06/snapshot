import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../../models/post.dart';
import '../../auth/providers/auth_providers.dart';
import '../../feed/providers/feed_providers.dart';
import '../data/search_repository.dart';

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(),
);

/// Follow suggestions for the current user.
final suggestedUsersProvider = FutureProvider.autoDispose<List<AppUser>>((
  ref,
) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const [];
  final following = ref.watch(followingIdsProvider).valueOrNull ?? const [];
  return ref
      .watch(searchRepositoryProvider)
      .suggestedUsers(currentUid: uid, followingIds: following);
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
