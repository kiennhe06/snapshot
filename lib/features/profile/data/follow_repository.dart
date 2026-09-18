import 'package:cloud_firestore/cloud_firestore.dart';

/// Manages follow relationships and keeps follower/following counts in sync.
class FollowRepository {
  FollowRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  /// True while [currentUid] follows [targetUid].
  Stream<bool> watchIsFollowing({
    required String currentUid,
    required String targetUid,
  }) {
    return _user(currentUid)
        .collection('following')
        .doc(targetUid)
        .snapshots()
        .map((snap) => snap.exists);
  }

  /// Follows [targetUid]: writes both edges and increments both counters in one
  /// transaction so counts never drift.
  Future<void> follow({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid == targetUid) return;
    final followingRef = _user(
      currentUid,
    ).collection('following').doc(targetUid);
    final followerRef = _user(
      targetUid,
    ).collection('followers').doc(currentUid);
    await _db.runTransaction((tx) async {
      final existing = await tx.get(followingRef);
      if (existing.exists) return; // already following
      final now = FieldValue.serverTimestamp();
      tx.set(followingRef, {'since': now});
      tx.set(followerRef, {'since': now});
      tx.set(_user(currentUid), {
        'followingCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
      tx.set(_user(targetUid), {
        'followersCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    });
  }

  Future<void> unfollow({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid == targetUid) return;
    final followingRef = _user(
      currentUid,
    ).collection('following').doc(targetUid);
    final followerRef = _user(
      targetUid,
    ).collection('followers').doc(currentUid);
    await _db.runTransaction((tx) async {
      final existing = await tx.get(followingRef);
      if (!existing.exists) return; // not following
      tx.delete(followingRef);
      tx.delete(followerRef);
      tx.set(_user(currentUid), {
        'followingCount': FieldValue.increment(-1),
      }, SetOptions(merge: true));
      tx.set(_user(targetUid), {
        'followersCount': FieldValue.increment(-1),
      }, SetOptions(merge: true));
    });
  }
}
