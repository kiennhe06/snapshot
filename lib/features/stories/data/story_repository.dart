import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/storage_service.dart';
import '../../../models/story.dart';

/// Stories: create (Cloudinary media, 24h expiry), read active ones, mark
/// viewed, and record interactive sticker responses (poll / slider / question).
class StoryRepository {
  StoryRepository({FirebaseFirestore? firestore, StorageService? storage})
    : _db = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? StorageService();

  final FirebaseFirestore _db;
  final StorageService _storage;

  CollectionReference<Map<String, dynamic>> get _stories =>
      _db.collection('stories');

  Future<String> createStory({
    required String uid,
    required File file,
    required bool isVideo,
    List<StorySticker> stickers = const [],
    bool closeFriendsOnly = false,
    List<String> closeFriends = const [],
    String? caption,
    String? addYoursPrompt,
    String? addYoursSourceId,
  }) async {
    final docRef = _stories.doc();
    final url = await _storage.uploadPostMedia(
      uid: uid,
      postId: docRef.id,
      file: file,
      contentType: isVideo ? 'video/mp4' : 'image/jpeg',
    );
    final now = DateTime.now();
    final story = Story(
      storyId: docRef.id,
      authorId: uid,
      mediaUrl: url,
      mediaType: isVideo ? 'video' : 'image',
      caption: caption,
      closeFriendsOnly: closeFriendsOnly,
      closeFriends: closeFriends,
      stickers: stickers,
      addYoursPrompt: addYoursPrompt,
      addYoursSourceId: addYoursSourceId,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
    );
    await docRef.set({
      ...story.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Active (non-expired) stories, newest first. Equality/range on a single
  /// field only (auto index). Audience filtering is applied by the caller.
  Stream<List<Story>> watchActiveStories() {
    return _stories
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => Story.fromMap(d.data())).toList();
          list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return list;
        });
  }

  Stream<List<Story>> watchUserStories(String uid) {
    return _stories
        .where('authorId', isEqualTo: uid)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => Story.fromMap(d.data())).toList();
          list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return list;
        });
  }

  Future<Story?> getStory(String storyId) async {
    final snap = await _stories.doc(storyId).get();
    final data = snap.data();
    return data == null ? null : Story.fromMap(data);
  }

  Future<void> deleteStory(String storyId) => _stories.doc(storyId).delete();

  // ---- Views -----------------------------------------------------------------

  Future<void> markViewed(String storyId, String uid) async {
    final viewRef = _stories.doc(storyId).collection('views').doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(viewRef);
      if (snap.exists) return;
      tx.set(viewRef, {'at': FieldValue.serverTimestamp()});
      tx.update(_stories.doc(storyId), {'viewsCount': FieldValue.increment(1)});
    });
  }

  Stream<bool> watchHasViewed(String storyId, String uid) => _stories
      .doc(storyId)
      .collection('views')
      .doc(uid)
      .snapshots()
      .map((s) => s.exists);

  Stream<List<String>> watchViewers(String storyId) => _stories
      .doc(storyId)
      .collection('views')
      .snapshots()
      .map((s) => s.docs.map((d) => d.id).toList());

  // ---- Sticker responses -----------------------------------------------------

  DocumentReference<Map<String, dynamic>> _agg(
    String storyId,
    String stickerId,
  ) => _stories.doc(storyId).collection('aggregates').doc(stickerId);
  DocumentReference<Map<String, dynamic>> _resp(
    String storyId,
    String stickerId,
    String uid,
  ) => _stories.doc(storyId).collection('responses').doc('${stickerId}__$uid');

  Stream<Map<String, dynamic>?> watchAggregate(
    String storyId,
    String stickerId,
  ) => _agg(storyId, stickerId).snapshots().map((s) => s.data());

  Stream<Map<String, dynamic>?> watchMyResponse(
    String storyId,
    String stickerId,
    String uid,
  ) => _resp(storyId, stickerId, uid).snapshots().map((s) => s.data());

  /// Vote a poll option (0/1). One vote per user; changing vote moves the count.
  Future<void> votePoll({
    required String storyId,
    required String stickerId,
    required String uid,
    required int optionIndex,
  }) async {
    await _db.runTransaction((tx) async {
      final respRef = _resp(storyId, stickerId, uid);
      final aggRef = _agg(storyId, stickerId);
      final prev = await tx.get(respRef);
      final aggSnap = await tx.get(aggRef);
      final counts = Map<String, dynamic>.from(
        (aggSnap.data()?['counts'] as Map<String, dynamic>?) ?? {},
      );
      if (prev.exists) {
        final old = (prev.data()?['option'] as num?)?.toInt();
        if (old == optionIndex) return;
        if (old != null) {
          counts['$old'] = ((counts['$old'] as num?)?.toInt() ?? 1) - 1;
        }
      }
      counts['$optionIndex'] =
          ((counts['$optionIndex'] as num?)?.toInt() ?? 0) + 1;
      tx.set(aggRef, {'counts': counts}, SetOptions(merge: true));
      tx.set(respRef, {'option': optionIndex});
    });
  }

  /// Answer an emoji-slider (value 0..1). Updates running average.
  Future<void> respondSlider({
    required String storyId,
    required String stickerId,
    required String uid,
    required double value,
  }) async {
    await _db.runTransaction((tx) async {
      final respRef = _resp(storyId, stickerId, uid);
      final aggRef = _agg(storyId, stickerId);
      final prev = await tx.get(respRef);
      final aggSnap = await tx.get(aggRef);
      var sum = (aggSnap.data()?['sum'] as num?)?.toDouble() ?? 0;
      var n = (aggSnap.data()?['n'] as num?)?.toInt() ?? 0;
      if (prev.exists) {
        sum -= (prev.data()?['value'] as num?)?.toDouble() ?? 0;
      } else {
        n += 1;
      }
      sum += value;
      tx.set(aggRef, {'sum': sum, 'n': n}, SetOptions(merge: true));
      tx.set(respRef, {'value': value});
    });
  }

  /// Free-text answer to a question sticker (author sees replies).
  Future<void> respondQuestion({
    required String storyId,
    required String stickerId,
    required String uid,
    required String text,
  }) {
    return _resp(
      storyId,
      stickerId,
      uid,
    ).set({'text': text, 'at': FieldValue.serverTimestamp()});
  }
}
