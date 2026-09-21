import 'package:cloud_firestore/cloud_firestore.dart';

/// Interactive sticker kinds placed on a story.
enum StickerType {
  poll,
  question,
  quiz,
  countdown,
  slider,
  text,
  hashtag,
  mention,
  location,
  music,
  gif,
}

StickerType stickerTypeFrom(String? s) => StickerType.values.firstWhere(
  (e) => e.name == s,
  orElse: () => StickerType.text,
);

/// A sticker on a story. [x]/[y] are 0..1 relative positions of the center.
class StorySticker {
  const StorySticker({
    required this.id,
    required this.type,
    this.x = 0.5,
    this.y = 0.5,
    this.data = const {},
  });

  final String id;
  final StickerType type;
  final double x;
  final double y;
  final Map<String, dynamic> data;

  factory StorySticker.fromMap(Map<String, dynamic> j) => StorySticker(
    id: j['id'] as String? ?? '',
    type: stickerTypeFrom(j['type'] as String?),
    x: (j['x'] as num?)?.toDouble() ?? 0.5,
    y: (j['y'] as num?)?.toDouble() ?? 0.5,
    data: (j['data'] as Map<String, dynamic>?) ?? const {},
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'x': x,
    'y': y,
    'data': data,
  };

  StorySticker copyWith({double? x, double? y, Map<String, dynamic>? data}) =>
      StorySticker(
        id: id,
        type: type,
        x: x ?? this.x,
        y: y ?? this.y,
        data: data ?? this.data,
      );
}

/// A story: `stories/{storyId}`. Expires 24h after creation.
class Story {
  const Story({
    required this.storyId,
    required this.authorId,
    required this.mediaUrl,
    required this.mediaType, // image | video
    this.caption,
    this.closeFriendsOnly = false,
    this.closeFriends = const [],
    this.stickers = const [],
    this.addYoursPrompt,
    this.addYoursSourceId,
    this.musicTitle,
    this.musicArtist,
    this.musicCoverUrl,
    this.musicPreviewUrl,
    this.musicUrl,
    this.viewsCount = 0,
    required this.createdAt,
    required this.expiresAt,
  });

  final String storyId;
  final String authorId;
  final String mediaUrl;
  final String mediaType;
  final String? caption;
  final bool closeFriendsOnly;

  /// Uids allowed to view when [closeFriendsOnly] (author's favorites snapshot).
  final List<String> closeFriends;
  final List<StorySticker> stickers;
  final String? addYoursPrompt;
  final String? addYoursSourceId;

  /// Attached music (iTunes track). [musicPreviewUrl] is a 30s audio clip.
  final String? musicTitle;
  final String? musicArtist;
  final String? musicCoverUrl;
  final String? musicPreviewUrl;
  final String? musicUrl;

  final int viewsCount;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool get isVideo => mediaType == 'video';
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get hasMusic => (musicTitle ?? '').isNotEmpty;

  factory Story.fromMap(Map<String, dynamic> j) {
    final rawStickers = (j['stickers'] as List<dynamic>?) ?? const [];
    return Story(
      storyId: j['storyId'] as String? ?? '',
      authorId: j['authorId'] as String? ?? '',
      mediaUrl: j['mediaUrl'] as String? ?? '',
      mediaType: j['mediaType'] as String? ?? 'image',
      caption: j['caption'] as String?,
      closeFriendsOnly: j['closeFriendsOnly'] as bool? ?? false,
      closeFriends:
          (j['closeFriends'] as List<dynamic>?)?.cast<String>() ?? const [],
      stickers: rawStickers
          .map((e) => StorySticker.fromMap(e as Map<String, dynamic>))
          .toList(),
      addYoursPrompt: j['addYoursPrompt'] as String?,
      addYoursSourceId: j['addYoursSourceId'] as String?,
      musicTitle: j['musicTitle'] as String?,
      musicArtist: j['musicArtist'] as String?,
      musicCoverUrl: j['musicCoverUrl'] as String?,
      musicPreviewUrl: j['musicPreviewUrl'] as String?,
      musicUrl: j['musicUrl'] as String?,
      viewsCount: (j['viewsCount'] as num?)?.toInt() ?? 0,
      createdAt: _toDate(j['createdAt']),
      expiresAt: _toDate(j['expiresAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'storyId': storyId,
    'authorId': authorId,
    'mediaUrl': mediaUrl,
    'mediaType': mediaType,
    'caption': caption,
    'closeFriendsOnly': closeFriendsOnly,
    'closeFriends': closeFriends,
    'stickers': stickers.map((s) => s.toMap()).toList(),
    'addYoursPrompt': addYoursPrompt,
    'addYoursSourceId': addYoursSourceId,
    'musicTitle': musicTitle,
    'musicArtist': musicArtist,
    'musicCoverUrl': musicCoverUrl,
    'musicPreviewUrl': musicPreviewUrl,
    'musicUrl': musicUrl,
    'viewsCount': viewsCount,
    'createdAt': Timestamp.fromDate(createdAt),
    'expiresAt': Timestamp.fromDate(expiresAt),
  };

  static DateTime _toDate(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.now();
  }
}

/// A profile highlight: `users/{uid}/highlights/{id}` referencing story ids.
class Highlight {
  const Highlight({
    required this.id,
    required this.title,
    required this.coverUrl,
    this.storyIds = const [],
  });

  final String id;
  final String title;
  final String coverUrl;
  final List<String> storyIds;

  factory Highlight.fromMap(Map<String, dynamic> j) => Highlight(
    id: j['id'] as String? ?? '',
    title: j['title'] as String? ?? '',
    coverUrl: j['coverUrl'] as String? ?? '',
    storyIds: (j['storyIds'] as List<dynamic>?)?.cast<String>() ?? const [],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'coverUrl': coverUrl,
    'storyIds': storyIds,
  };
}
