import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/storage_service.dart';
import '../../../models/post.dart';

/// Draft media selected by the user before upload. Mutable so the composer can
/// attach an alt text per item.
class DraftMedia {
  DraftMedia({required this.file, required this.isVideo, this.altText = ''});
  final File file;
  final bool isVideo;
  String altText;
}

/// Reads/writes posts. Profile lists (grid, reels, tagged, pinned, archived)
/// are derived client-side from equality/array-contains queries, so NO
/// composite Firestore index is required.
class PostRepository {
  PostRepository({FirebaseFirestore? firestore, StorageService? storage})
    : _db = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? StorageService();

  final FirebaseFirestore _db;
  final StorageService _storage;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');

  /// Posts on [uid]'s profile — authored OR collaborated (array-contains only;
  /// no composite index). Sorted client-side.
  Stream<List<Post>> watchAuthoredPosts(String uid) {
    return _posts.where('contributorIds', arrayContains: uid).snapshots().map((
      snap,
    ) {
      final list = snap.docs.map((d) => Post.fromMap(d.data())).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Posts where [uid] is tagged (array-contains only; no composite index).
  Stream<List<Post>> watchTaggedPosts(String uid) {
    return _posts.where('taggedUserIds', arrayContains: uid).snapshots().map((
      snap,
    ) {
      final list = snap.docs
          .where((d) => (d.data()['isArchived'] as bool? ?? false) == false)
          .map((d) => Post.fromMap(d.data()))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<Post?> getPost(String postId) async {
    final snap = await _posts.doc(postId).get();
    final data = snap.data();
    return data == null ? null : Post.fromMap(data);
  }

  /// Creates a post: uploads each media file, writes the doc, and bumps every
  /// contributor's postsCount atomically.
  Future<String> createPost({
    required String uid,
    required String caption,
    required List<DraftMedia> media,
    List<String> taggedUserIds = const [],
    List<String> coAuthorIds = const [],
    String? location,
    bool commentsDisabled = false,
    bool likesHidden = false,
  }) async {
    if (media.isEmpty) {
      throw ArgumentError('Bài đăng cần ít nhất một ảnh hoặc video.');
    }
    final docRef = _posts.doc();
    final uploaded = <PostMedia>[];
    for (final item in media) {
      final url = await _storage.uploadPostMedia(
        uid: uid,
        postId: docRef.id,
        file: item.file,
        contentType: item.isVideo ? 'video/mp4' : 'image/jpeg',
      );
      uploaded.add(
        PostMedia(
          url: url,
          type: item.isVideo ? 'video' : 'image',
          altText: item.altText.trim(),
        ),
      );
    }

    final mediaType = media.length > 1
        ? 'carousel'
        : (media.first.isVideo ? 'video' : 'image');
    final contributorIds = <String>[
      uid,
      ...coAuthorIds.where((id) => id != uid),
    ];

    final post = Post(
      postId: docRef.id,
      authorId: uid,
      caption: caption.trim(),
      mediaType: mediaType,
      media: uploaded,
      contributorIds: contributorIds,
      taggedUserIds: taggedUserIds,
      hashtags: _extractHashtags(caption),
      location: location?.trim().isEmpty == true ? null : location?.trim(),
      commentsDisabled: commentsDisabled,
      likesHidden: likesHidden,
      createdAt: DateTime.now(),
    );

    final batch = _db.batch();
    batch.set(docRef, {
      ...post.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    for (final contributor in contributorIds) {
      batch.set(_db.collection('users').doc(contributor), {
        'postsCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    }
    await batch.commit();
    return docRef.id;
  }

  /// Edits an existing post's text/settings (media is not changed here).
  Future<void> updatePost({
    required String postId,
    required String caption,
    String? location,
    List<String>? taggedUserIds,
    List<String>? altTexts,
    bool? commentsDisabled,
    bool? likesHidden,
  }) async {
    final data = <String, dynamic>{
      'caption': caption.trim(),
      'hashtags': _extractHashtags(caption),
      'location': (location?.trim().isEmpty ?? true) ? null : location!.trim(),
    };
    if (taggedUserIds != null) data['taggedUserIds'] = taggedUserIds;
    if (commentsDisabled != null) data['commentsDisabled'] = commentsDisabled;
    if (likesHidden != null) data['likesHidden'] = likesHidden;
    if (altTexts != null) {
      // Merge alt texts into existing media entries by index.
      final snap = await _posts.doc(postId).get();
      final current = Post.fromMap(snap.data() ?? {});
      final updated = <Map<String, dynamic>>[];
      for (var i = 0; i < current.media.length; i++) {
        final alt = i < altTexts.length
            ? altTexts[i]
            : current.media[i].altText;
        updated.add(current.media[i].copyWith(altText: alt).toMap());
      }
      data['media'] = updated;
    }
    await _posts.doc(postId).set(data, SetOptions(merge: true));
  }

  /// Deletes a post and decrements every contributor's postsCount.
  Future<void> deletePost(String postId) async {
    final snap = await _posts.doc(postId).get();
    if (!snap.exists) return;
    final post = Post.fromMap(snap.data()!);
    final batch = _db.batch();
    batch.delete(_posts.doc(postId));
    for (final contributor in post.contributorIds) {
      batch.set(_db.collection('users').doc(contributor), {
        'postsCount': FieldValue.increment(-1),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> setArchived(String postId, bool archived) {
    return _posts.doc(postId).set({
      'isArchived': archived,
      if (archived) 'isPinned': false,
      if (archived) 'pinnedOrder': null,
    }, SetOptions(merge: true));
  }

  /// Pins a post. Enforces a maximum of 3 pinned posts per author.
  Future<void> pin(String uid, String postId) async {
    final pinned = await _posts
        .where('authorId', isEqualTo: uid)
        .where('isPinned', isEqualTo: true)
        .get();
    if (pinned.docs.length >= 3) {
      throw StateError('Chỉ được ghim tối đa 3 bài.');
    }
    await _posts.doc(postId).set({
      'isPinned': true,
      'pinnedOrder': pinned.docs.length,
    }, SetOptions(merge: true));
  }

  Future<void> unpin(String postId) {
    return _posts.doc(postId).set({
      'isPinned': false,
      'pinnedOrder': null,
    }, SetOptions(merge: true));
  }

  List<String> _extractHashtags(String caption) {
    final matches = RegExp(r'#(\w+)').allMatches(caption);
    return matches.map((m) => m.group(1)!.toLowerCase()).toList();
  }
}
