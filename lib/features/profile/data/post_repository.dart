import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/storage_service.dart';
import '../../../models/post.dart';

/// Draft media selected by the user before upload.
class DraftMedia {
  const DraftMedia({required this.file, required this.isVideo});
  final File file;
  final bool isVideo;
}

/// Reads/writes posts. Profile lists (grid, reels, tagged, pinned, archived)
/// are derived client-side from two equality-only queries, so NO composite
/// Firestore index is required.
class PostRepository {
  PostRepository({FirebaseFirestore? firestore, StorageService? storage})
    : _db = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? StorageService();

  final FirebaseFirestore _db;
  final StorageService _storage;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');

  /// All posts authored by [uid] (equality-only query; sorted client-side).
  Stream<List<Post>> watchAuthoredPosts(String uid) {
    return _posts.where('authorId', isEqualTo: uid).snapshots().map((snap) {
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

  /// Creates a post: uploads each media file, writes the doc, and bumps the
  /// author's postsCount atomically.
  Future<String> createPost({
    required String uid,
    required String caption,
    required List<DraftMedia> media,
    List<String> taggedUserIds = const [],
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
      uploaded.add(PostMedia(url: url, type: item.isVideo ? 'video' : 'image'));
    }

    final mediaType = media.length > 1
        ? 'carousel'
        : (media.first.isVideo ? 'video' : 'image');

    final post = Post(
      postId: docRef.id,
      authorId: uid,
      caption: caption.trim(),
      mediaType: mediaType,
      media: uploaded,
      taggedUserIds: taggedUserIds,
      hashtags: _extractHashtags(caption),
      createdAt: DateTime.now(),
    );

    final batch = _db.batch();
    batch.set(docRef, {
      ...post.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_db.collection('users').doc(uid), {
      'postsCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await batch.commit();
    return docRef.id;
  }

  Future<void> setArchived(String postId, bool archived) {
    return _posts.doc(postId).set({
      'isArchived': archived,
      // Archiving also unpins.
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
