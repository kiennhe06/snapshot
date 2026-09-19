import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/post.dart';

/// One page of posts plus the cursor needed to fetch the next page.
class PostPage {
  const PostPage({
    required this.posts,
    required this.nextCursor,
    required this.hasMore,
  });
  final List<Post> posts;
  final DateTime? nextCursor;
  final bool hasMore;
}

/// Reads posts for the home feed and Explore using cursor pagination on
/// `createdAt`. This needs only the automatic single-field index (no composite
/// index) and has no `whereIn` size limit; audience filtering (following /
/// favorites / explore) is applied by the caller. For large scale this can be
/// replaced with a Cloud Functions fan-out timeline later.
class FeedRepository {
  FeedRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');

  /// Fetches one page of recent posts (newest first).
  Future<PostPage> fetchPage({DateTime? startAfter, int pageSize = 15}) async {
    Query<Map<String, dynamic>> q = _posts.orderBy(
      'createdAt',
      descending: true,
    );
    if (startAfter != null) {
      q = q.startAfter([Timestamp.fromDate(startAfter)]);
    }
    q = q.limit(pageSize);

    final snap = await q.get();
    final posts = snap.docs
        .map((d) => Post.fromMap(d.data()))
        .where((p) => !p.isArchived)
        .toList();
    final nextCursor = snap.docs.isEmpty
        ? null
        : Post.fromMap(snap.docs.last.data()).createdAt;
    return PostPage(
      posts: posts,
      nextCursor: nextCursor,
      hasMore: snap.docs.length == pageSize,
    );
  }

  /// Video posts using a given music title (equality-only; no composite index).
  Stream<List<Post>> watchPostsByMusic(String musicTitle) {
    return _posts.where('musicTitle', isEqualTo: musicTitle).snapshots().map((
      snap,
    ) {
      final list = snap.docs
          .map((d) => Post.fromMap(d.data()))
          .where((p) => !p.isArchived)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ---- Favorites (close friends) ---------------------------------------------

  DocumentReference<Map<String, dynamic>> _favDoc(
    String uid,
    String targetUid,
  ) => _db.collection('users').doc(uid).collection('favorites').doc(targetUid);

  Stream<List<String>> watchFavoriteIds(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }

  Future<void> setFavorite({
    required String uid,
    required String targetUid,
    required bool favorite,
  }) {
    final ref = _favDoc(uid, targetUid);
    return favorite
        ? ref.set({'since': FieldValue.serverTimestamp()})
        : ref.delete();
  }

  // ---- Likes ------------------------------------------------------------------

  Stream<bool> watchIsLiked(String postId, String uid) {
    return _posts
        .doc(postId)
        .collection('likes')
        .doc(uid)
        .snapshots()
        .map((s) => s.exists);
  }

  /// Toggles a like and keeps likesCount in sync in one transaction.
  Future<void> toggleLike(String postId, String uid) async {
    final likeRef = _posts.doc(postId).collection('likes').doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(likeRef);
      if (snap.exists) {
        tx.delete(likeRef);
        tx.update(_posts.doc(postId), {'likesCount': FieldValue.increment(-1)});
      } else {
        tx.set(likeRef, {'at': FieldValue.serverTimestamp()});
        tx.update(_posts.doc(postId), {'likesCount': FieldValue.increment(1)});
      }
    });
  }
}
