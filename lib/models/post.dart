import 'package:cloud_firestore/cloud_firestore.dart';

/// A single media item inside a post.
class PostMedia {
  const PostMedia({
    required this.url,
    required this.type,
    this.thumbUrl,
    this.altText = '',
    this.width = 0,
    this.height = 0,
    this.durationMs = 0,
  });

  final String url;

  /// `image` or `video`.
  final String type;
  final String? thumbUrl;

  /// Accessibility description for screen readers.
  final String altText;
  final int width;
  final int height;
  final int durationMs;

  factory PostMedia.fromMap(Map<String, dynamic> json) => PostMedia(
    url: json['url'] as String? ?? '',
    type: json['type'] as String? ?? 'image',
    thumbUrl: json['thumbUrl'] as String?,
    altText: json['altText'] as String? ?? '',
    width: (json['width'] as num?)?.toInt() ?? 0,
    height: (json['height'] as num?)?.toInt() ?? 0,
    durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'url': url,
    'type': type,
    'thumbUrl': thumbUrl,
    'altText': altText,
    'width': width,
    'height': height,
    'durationMs': durationMs,
  };

  PostMedia copyWith({String? altText}) => PostMedia(
    url: url,
    type: type,
    thumbUrl: thumbUrl,
    altText: altText ?? this.altText,
    width: width,
    height: height,
    durationMs: durationMs,
  );
}

/// Post document, mirrors `posts/{postId}`.
class Post {
  const Post({
    required this.postId,
    required this.authorId,
    required this.caption,
    required this.mediaType,
    required this.media,
    this.contributorIds = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    this.taggedUserIds = const [],
    this.hashtags = const [],
    this.location,
    this.musicTitle,
    this.remixOfPostId,
    this.commentsDisabled = false,
    this.likesHidden = false,
    this.isArchived = false,
    this.isPinned = false,
    this.pinnedOrder,
    required this.createdAt,
  });

  final String postId;
  final String authorId;
  final String caption;

  /// `image`, `video` or `carousel`.
  final String mediaType;
  final List<PostMedia> media;

  /// Everyone whose profile this post appears on: author + collaborators.
  final List<String> contributorIds;
  final int likesCount;
  final int commentsCount;
  final List<String> taggedUserIds;
  final List<String> hashtags;
  final String? location;
  final String? musicTitle;
  final String? remixOfPostId;
  final bool commentsDisabled;
  final bool likesHidden;
  final bool isArchived;
  final bool isPinned;

  /// 0..2 when pinned (position among the max 3 pinned posts).
  final int? pinnedOrder;
  final DateTime createdAt;

  /// Collaborators = contributors minus the original author.
  List<String> get coAuthorIds =>
      contributorIds.where((id) => id != authorId).toList();

  /// Cover image for the profile grid (thumb of the first media item).
  String get coverUrl =>
      media.isEmpty ? '' : (media.first.thumbUrl ?? media.first.url);

  bool get isVideo => mediaType == 'video';
  bool get isCarousel => mediaType == 'carousel';

  factory Post.fromMap(Map<String, dynamic> json) {
    final rawMedia = (json['media'] as List<dynamic>?) ?? const [];
    return Post(
      postId: json['postId'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      mediaType: json['mediaType'] as String? ?? 'image',
      media: rawMedia
          .map((e) => PostMedia.fromMap(e as Map<String, dynamic>))
          .toList(),
      contributorIds:
          (json['contributorIds'] as List<dynamic>?)?.cast<String>() ??
          const [],
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
      taggedUserIds:
          (json['taggedUserIds'] as List<dynamic>?)?.cast<String>() ?? const [],
      hashtags:
          (json['hashtags'] as List<dynamic>?)?.cast<String>() ?? const [],
      location: json['location'] as String?,
      musicTitle: json['musicTitle'] as String?,
      remixOfPostId: json['remixOfPostId'] as String?,
      commentsDisabled: json['commentsDisabled'] as bool? ?? false,
      likesHidden: json['likesHidden'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
      pinnedOrder: (json['pinnedOrder'] as num?)?.toInt(),
      createdAt: _toDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'postId': postId,
    'authorId': authorId,
    'caption': caption,
    'mediaType': mediaType,
    'media': media.map((m) => m.toMap()).toList(),
    'contributorIds': contributorIds,
    'likesCount': likesCount,
    'commentsCount': commentsCount,
    'taggedUserIds': taggedUserIds,
    'hashtags': hashtags,
    'location': location,
    'musicTitle': musicTitle,
    'remixOfPostId': remixOfPostId,
    'commentsDisabled': commentsDisabled,
    'likesHidden': likesHidden,
    'isArchived': isArchived,
    'isPinned': isPinned,
    'pinnedOrder': pinnedOrder,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  static DateTime _toDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
