import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/comment.dart';

/// Comments + replies under a post. To avoid composite indexes we stream ALL
/// comments of a post and split roots/replies client-side.
class CommentRepository {
  CommentRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _comments(String postId) =>
      _db.collection('posts').doc(postId).collection('comments');

  /// Streams all comments of a post (unsorted; caller splits/sorts).
  Stream<List<Comment>> watchComments(String postId) {
    return _comments(postId).snapshots().map(
      (snap) => snap.docs.map((d) => Comment.fromMap(d.data())).toList(),
    );
  }

  Future<void> addComment({
    required String postId,
    required String uid,
    required String text,
    String? parentId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final docRef = _comments(postId).doc();
    final comment = Comment(
      commentId: docRef.id,
      postId: postId,
      authorId: uid,
      text: trimmed,
      parentId: parentId,
      createdAt: DateTime.now(),
    );
    final batch = _db.batch();
    batch.set(docRef, {
      ...comment.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Bump the post's comment counter.
    batch.update(_db.collection('posts').doc(postId), {
      'commentsCount': FieldValue.increment(1),
    });
    // Bump the parent's reply counter.
    if (parentId != null) {
      batch.update(_comments(postId).doc(parentId), {
        'replyCount': FieldValue.increment(1),
      });
    }
    await batch.commit();
  }

  Future<void> deleteComment({
    required String postId,
    required Comment comment,
  }) async {
    final batch = _db.batch();
    var removed = 1;
    // If it's a root comment, also remove its replies.
    if (!comment.isReply) {
      final replies = await _comments(
        postId,
      ).where('parentId', isEqualTo: comment.commentId).get();
      for (final r in replies.docs) {
        batch.delete(r.reference);
      }
      removed += replies.docs.length;
    } else {
      batch.update(_comments(postId).doc(comment.parentId), {
        'replyCount': FieldValue.increment(-1),
      });
    }
    batch.delete(_comments(postId).doc(comment.commentId));
    batch.update(_db.collection('posts').doc(postId), {
      'commentsCount': FieldValue.increment(-removed),
    });
    await batch.commit();
  }

  /// Author of the post can pin/unpin a comment.
  Future<void> setPinned({
    required String postId,
    required String commentId,
    required bool pinned,
  }) {
    return _comments(
      postId,
    ).doc(commentId).set({'pinned': pinned}, SetOptions(merge: true));
  }

  Stream<bool> watchIsLiked({
    required String postId,
    required String commentId,
    required String uid,
  }) {
    return _comments(postId)
        .doc(commentId)
        .collection('likes')
        .doc(uid)
        .snapshots()
        .map((s) => s.exists);
  }

  Future<void> toggleLike({
    required String postId,
    required String commentId,
    required String uid,
  }) async {
    final likeRef = _comments(
      postId,
    ).doc(commentId).collection('likes').doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(likeRef);
      final commentRef = _comments(postId).doc(commentId);
      if (snap.exists) {
        tx.delete(likeRef);
        tx.update(commentRef, {'likesCount': FieldValue.increment(-1)});
      } else {
        tx.set(likeRef, {'at': FieldValue.serverTimestamp()});
        tx.update(commentRef, {'likesCount': FieldValue.increment(1)});
      }
    });
  }
}
