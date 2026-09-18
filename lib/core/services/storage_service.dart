import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

/// Uploads files to Firebase Storage and returns their download URLs.
class StorageService {
  StorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Uploads a user's avatar to `users/{uid}/avatar.jpg`, returns the URL.
  Future<String> uploadAvatar(String uid, File file) async {
    final ref = _storage.ref('users/$uid/avatar.jpg');
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }

  /// Uploads a post media file to `posts/{uid}/{postId}/{fileId}`.
  Future<String> uploadPostMedia({
    required String uid,
    required String postId,
    required File file,
    required String contentType,
  }) async {
    final fileId = const Uuid().v4();
    final ext = contentType.startsWith('video') ? 'mp4' : 'jpg';
    final ref = _storage.ref('posts/$uid/$postId/$fileId.$ext');
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: contentType),
    );
    return task.ref.getDownloadURL();
  }
}
