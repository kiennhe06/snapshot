import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/comment.dart';
import '../../../models/post.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/comment_repository.dart';
import '../data/relation_repository.dart';
import '../data/save_repository.dart';

// Repositories
final commentRepositoryProvider = Provider<CommentRepository>(
  (ref) => CommentRepository(),
);
final saveRepositoryProvider = Provider<SaveRepository>(
  (ref) => SaveRepository(),
);
final relationRepositoryProvider = Provider<RelationRepository>(
  (ref) => RelationRepository(),
);

// Comments
final commentsProvider = StreamProvider.autoDispose
    .family<List<Comment>, String>((ref, postId) {
      return ref.watch(commentRepositoryProvider).watchComments(postId);
    });

final isCommentLikedProvider = StreamProvider.autoDispose
    .family<bool, ({String postId, String commentId})>((ref, arg) {
      final uid = ref.watch(authStateProvider).valueOrNull?.uid;
      if (uid == null) return Stream.value(false);
      return ref
          .watch(commentRepositoryProvider)
          .watchIsLiked(postId: arg.postId, commentId: arg.commentId, uid: uid);
    });

// Saves / bookmarks
final isSavedProvider = StreamProvider.autoDispose.family<bool, String>((
  ref,
  postId,
) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(false);
  return ref.watch(saveRepositoryProvider).watchIsSaved(uid, postId);
});

final collectionsProvider = StreamProvider.autoDispose<List<SaveCollection>>((
  ref,
) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(saveRepositoryProvider).watchCollections(uid);
});

final savedPostsProvider = StreamProvider.autoDispose
    .family<List<Post>, String?>((ref, collectionId) {
      final uid = ref.watch(authStateProvider).valueOrNull?.uid;
      if (uid == null) return Stream.value(const []);
      return ref
          .watch(saveRepositoryProvider)
          .watchSavedPosts(uid, collectionId: collectionId);
    });

// Relations
final _relStream = <String>['blocked', 'muted', 'restricted'];

final blockedIdsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(relationRepositoryProvider).watchIds(uid, _relStream[0]);
});
final mutedIdsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(relationRepositoryProvider).watchIds(uid, _relStream[1]);
});
final restrictedIdsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(relationRepositoryProvider).watchIds(uid, _relStream[2]);
});

final hiddenWordsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(relationRepositoryProvider).watchHiddenWords(uid);
});
