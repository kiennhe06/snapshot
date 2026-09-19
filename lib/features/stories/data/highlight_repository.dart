import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/story.dart';

/// Profile story highlights: `users/{uid}/highlights/{id}`.
class HighlightRepository {
  HighlightRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('highlights');

  Stream<List<Highlight>> watchHighlights(String uid) {
    return _col(uid).snapshots().map(
      (snap) => snap.docs.map((d) => Highlight.fromMap(d.data())).toList(),
    );
  }

  Future<void> createHighlight({
    required String uid,
    required String title,
    required String coverUrl,
    required List<String> storyIds,
  }) {
    final ref = _col(uid).doc();
    return ref.set(
      Highlight(
        id: ref.id,
        title: title.trim(),
        coverUrl: coverUrl,
        storyIds: storyIds,
      ).toMap(),
    );
  }

  Future<void> deleteHighlight(String uid, String id) =>
      _col(uid).doc(id).delete();
}
