import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants.dart';

/// Uploads media to Cloudinary (free, no credit card) via *unsigned* upload,
/// and returns the hosted URL. Keeps the same public API the rest of the app
/// expects, so switching providers touches only this file.
class StorageService {
  StorageService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _endpoint(bool isVideo) {
    final resource = isVideo ? 'video' : 'image';
    return Uri.parse(
      'https://api.cloudinary.com/v1_1/'
      '${AppConfig.cloudinaryCloudName}/$resource/upload',
    );
  }

  /// Uploads a user's avatar, returns its URL.
  Future<String> uploadAvatar(String uid, File file) {
    return _upload(file: file, isVideo: false, folder: 'users/$uid');
  }

  /// Uploads a post media file, returns its URL.
  Future<String> uploadPostMedia({
    required String uid,
    required String postId,
    required File file,
    required String contentType,
  }) {
    final isVideo = contentType.startsWith('video');
    return _upload(file: file, isVideo: isVideo, folder: 'posts/$uid/$postId');
  }

  /// Uploads a chat attachment (image, video or voice note), returns its URL.
  /// Voice notes and video both use Cloudinary's `video` resource endpoint.
  Future<String> uploadChatMedia({
    required String chatId,
    required File file,
    required bool isVideo,
  }) {
    return _upload(file: file, isVideo: isVideo, folder: 'chats/$chatId');
  }

  /// Performs the unsigned multipart upload and extracts `secure_url`.
  Future<String> _upload({
    required File file,
    required bool isVideo,
    required String folder,
  }) async {
    final request = http.MultipartRequest('POST', _endpoint(isVideo))
      ..fields['upload_preset'] = AppConfig.cloudinaryUploadPreset
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await _client.send(request);
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw StorageException('Tải media thất bại (${streamed.statusCode}).');
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    final url = json['secure_url'] as String?;
    if (url == null) {
      throw StorageException('Phản hồi Cloudinary không hợp lệ.');
    }
    return url;
  }
}

/// Thrown when a media upload fails. Carries a friendly Vietnamese message.
class StorageException implements Exception {
  StorageException(this.message);
  final String message;
  @override
  String toString() => message;
}
