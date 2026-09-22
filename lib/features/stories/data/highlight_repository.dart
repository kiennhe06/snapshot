import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/storage_service.dart';
import '../../../models/story.dart';

/// Profile story highlights: `users/{uid}/highlights/{id}`.
class HighlightRepository {
  HighlightRepository({FirebaseFirestore? firestore, StorageService? storage})
    : _db = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? StorageService();

  final FirebaseFirestore _db;
  final StorageService _storage;

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

  /// Creates a highlight directly from a picked image (no active story needed).
  /// The image becomes the cover; [Highlight.storyIds] stays empty and the
  /// viewer renders the cover as a single-frame highlight.
  Future<void> createHighlightFromMedia({
    required String uid,
    required String title,
    required File file,
  }) async {
    final ref = _col(uid).doc();
    final url = await _storage.uploadPostMedia(
      uid: uid,
      postId: 'highlight_${ref.id}',
      file: file,
      contentType: 'image/jpeg',
    );
    await ref.set(
      Highlight(
        id: ref.id,
        title: title.trim(),
        coverUrl: url,
        storyIds: const [],
      ).toMap(),
    );
  }

  Future<void> deleteHighlight(String uid, String id) =>
      _col(uid).doc(id).delete();
}
