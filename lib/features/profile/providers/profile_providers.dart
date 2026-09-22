import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/storage_service.dart';
import '../../../models/app_user.dart';
import '../../../models/post.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/follow_repository.dart';
import '../data/post_repository.dart';
import '../data/user_repository.dart';

/// Data-layer singletons.
final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(),
);
final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(),
);
final postRepositoryProvider = Provider<PostRepository>(
  (ref) => PostRepository(),
);
final followRepositoryProvider = Provider<FollowRepository>(
  (ref) => FollowRepository(),
);

/// A user's profile document.
final userProfileProvider = StreamProvider.autoDispose.family<AppUser?, String>(
  (ref, uid) {
    return ref.watch(userRepositoryProvider).watchUser(uid);
  },
);

/// The signed-in user's own profile (convenience).
final myProfileProvider = StreamProvider.autoDispose<AppUser?>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchUser(uid);
});

/// All posts authored by a user (drives grid / reels / pinned / archived).
final authoredPostsProvider = StreamProvider.autoDispose
    .family<List<Post>, String>((ref, uid) {
      return ref.watch(postRepositoryProvider).watchAuthoredPosts(uid);
    });

/// Posts a user is tagged in.
final taggedPostsProvider = StreamProvider.autoDispose
    .family<List<Post>, String>((ref, uid) {
      return ref.watch(postRepositoryProvider).watchTaggedPosts(uid);
    });

/// AppUser list the current user follows (for tag / collab pickers).
final followingUsersProvider = FutureProvider.autoDispose<List<AppUser>>((
  ref,
) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const [];
  final ids = await ref
      .watch(followRepositoryProvider)
      .watchFollowingIds(uid)
      .first;
  final repo = ref.watch(userRepositoryProvider);
  final users = <AppUser>[];
  for (final id in ids) {
    final u = await repo.getUser(id);
    if (u != null) users.add(u);
  }
  return users;
});

/// Resolved follower/following list for any user. Key: (uid, followers?).
final followListProvider = FutureProvider.autoDispose
    .family<List<AppUser>, ({String uid, bool followers})>((ref, arg) async {
      final repo = ref.watch(followRepositoryProvider);
      final ids = await (arg.followers
              ? repo.watchFollowerIds(arg.uid)
              : repo.watchFollowingIds(arg.uid))
          .first;
      final ur = ref.watch(userRepositoryProvider);
      final users = <AppUser>[];
      for (final id in ids) {
        final u = await ur.getUser(id);
        if (u != null) users.add(u);
      }
      return users;
    });

/// Whether the current user follows [targetUid].
final isFollowingProvider = StreamProvider.autoDispose.family<bool, String>((
  ref,
  targetUid,
) {
  final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (currentUid == null) return Stream.value(false);
  return ref
      .watch(followRepositoryProvider)
      .watchIsFollowing(currentUid: currentUid, targetUid: targetUid);
});
