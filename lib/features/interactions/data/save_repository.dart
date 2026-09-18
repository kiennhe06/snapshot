import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/post.dart';

/// A saved-posts collection (bookmark folder).
class SaveCollection {
  const SaveCollection({required this.id, required this.name, this.count = 0});
  final String id;
  final String name;
  final int count;

  factory SaveCollection.fromMap(Map<String, dynamic> j) => SaveCollection(
    id: j['collectionId'] as String? ?? '',
    name: j['name'] as String? ?? '',
    count: (j['count'] as num?)?.toInt() ?? 0,
  );
}

/// Bookmarks under `users/{uid}/saved/{postId}` and folders under
/// `users/{uid}/collections/{collectionId}`.
class SaveRepository {
  SaveRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _saved(String uid) =>
      _db.collection('users').doc(uid).collection('saved');
  CollectionReference<Map<String, dynamic>> _collections(String uid) =>
      _db.collection('users').doc(uid).collection('collections');

  Stream<bool> watchIsSaved(String uid, String postId) =>
      _saved(uid).doc(postId).snapshots().map((s) => s.exists);

  Future<void> toggleSave({
    required String uid,
    required String postId,
    String? collectionId,
  }) async {
    final ref = _saved(uid).doc(postId);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
    } else {
      await ref.set({
        'postId': postId,
        'collectionId': collectionId,
        'savedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> setCollection({
    required String uid,
    required String postId,
    String? collectionId,
  }) {
    return _saved(uid).doc(postId).set({
      'postId': postId,
      'collectionId': collectionId,
      'savedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Saved posts, optionally filtered to one [collectionId]. Loads each post doc.
  Stream<List<Post>> watchSavedPosts(String uid, {String? collectionId}) {
    return _saved(uid).snapshots().asyncMap((snap) async {
      var docs = snap.docs;
      if (collectionId != null) {
        docs = docs
            .where((d) => d.data()['collectionId'] == collectionId)
            .toList();
      }
      final posts = <Post>[];
      for (final d in docs) {
        final ps = await _db.collection('posts').doc(d.id).get();
        final data = ps.data();
        if (data != null) posts.add(Post.fromMap(data));
      }
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    });
  }

  Stream<List<SaveCollection>> watchCollections(String uid) {
    return _collections(uid).snapshots().map(
      (snap) => snap.docs.map((d) => SaveCollection.fromMap(d.data())).toList(),
    );
  }

  Future<void> createCollection({required String uid, required String name}) {
    final ref = _collections(uid).doc();
    return ref.set({
      'collectionId': ref.id,
      'name': name.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
