import 'package:cloud_firestore/cloud_firestore.dart';

/// Block / mute / restrict relationships, reports, and hidden-word filters.
class RelationRepository {
  RelationRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _sub(String uid, String name) =>
      _db.collection('users').doc(uid).collection(name);

  // ---- Block / mute / restrict ----------------------------------------------

  Stream<List<String>> watchIds(String uid, String kind) =>
      _sub(uid, kind).snapshots().map((s) => s.docs.map((d) => d.id).toList());

  Stream<bool> watchHas(String uid, String kind, String targetUid) =>
      _sub(uid, kind).doc(targetUid).snapshots().map((s) => s.exists);

  Future<void> setRelation({
    required String uid,
    required String kind, // 'blocked' | 'muted' | 'restricted'
    required String targetUid,
    required bool on,
  }) {
    final ref = _sub(uid, kind).doc(targetUid);
    return on ? ref.set({'at': FieldValue.serverTimestamp()}) : ref.delete();
  }

  // ---- Reports ---------------------------------------------------------------

  Future<void> report({
    required String reporterId,
    required String targetType, // 'post' | 'user'
    required String targetId,
    required String reason,
  }) {
    return _db.collection('reports').add({
      'reporterId': reporterId,
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---- Hidden words (comment keyword filter) --------------------------------

  Stream<List<String>> watchHiddenWords(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      final list = snap.data()?['hiddenWords'] as List<dynamic>?;
      return list?.cast<String>() ?? const [];
    });
  }

  Future<void> setHiddenWords(String uid, List<String> words) {
    return _db.collection('users').doc(uid).set({
      'hiddenWords': words,
    }, SetOptions(merge: true));
  }
}
