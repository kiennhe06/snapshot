import 'package:cloud_firestore/cloud_firestore.dart';

/// A comment (or reply) under a post: `posts/{postId}/comments/{commentId}`.
/// A reply has [parentId] set to the root comment id; root comments have null.
class Comment {
  const Comment({
    required this.commentId,
    required this.postId,
    required this.authorId,
    required this.text,
    this.parentId,
    this.likesCount = 0,
    this.replyCount = 0,
    this.pinned = false,
    required this.createdAt,
  });

  final String commentId;
  final String postId;
  final String authorId;
  final String text;
  final String? parentId;
  final int likesCount;
  final int replyCount;
  final bool pinned;
  final DateTime createdAt;

  bool get isReply => parentId != null;

  factory Comment.fromMap(Map<String, dynamic> json) {
    return Comment(
      commentId: json['commentId'] as String? ?? '',
      postId: json['postId'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      text: json['text'] as String? ?? '',
      parentId: json['parentId'] as String?,
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
      pinned: json['pinned'] as bool? ?? false,
      createdAt: _toDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'commentId': commentId,
    'postId': postId,
    'authorId': authorId,
    'text': text,
    'parentId': parentId,
    'likesCount': likesCount,
    'replyCount': replyCount,
    'pinned': pinned,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  static DateTime _toDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
