/// A locally-saved post draft (not yet uploaded). Media is referenced by local
/// file path; if the OS clears the temp file the draft may lose that item.
class DraftItem {
  const DraftItem({
    required this.path,
    required this.isVideo,
    this.altText = '',
  });
  final String path;
  final bool isVideo;
  final String altText;

  factory DraftItem.fromMap(Map<String, dynamic> j) => DraftItem(
    path: j['path'] as String? ?? '',
    isVideo: j['isVideo'] as bool? ?? false,
    altText: j['altText'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'path': path,
    'isVideo': isVideo,
    'altText': altText,
  };
}

class PostDraft {
  const PostDraft({
    required this.id,
    required this.caption,
    required this.items,
    this.location,
    this.taggedUserIds = const [],
    this.coAuthorIds = const [],
    this.commentsDisabled = false,
    this.likesHidden = false,
    required this.updatedAt,
  });

  final String id;
  final String caption;
  final List<DraftItem> items;
  final String? location;
  final List<String> taggedUserIds;
  final List<String> coAuthorIds;
  final bool commentsDisabled;
  final bool likesHidden;
  final DateTime updatedAt;

  factory PostDraft.fromMap(Map<String, dynamic> j) => PostDraft(
    id: j['id'] as String? ?? '',
    caption: j['caption'] as String? ?? '',
    items: ((j['items'] as List<dynamic>?) ?? const [])
        .map((e) => DraftItem.fromMap(e as Map<String, dynamic>))
        .toList(),
    location: j['location'] as String?,
    taggedUserIds:
        (j['taggedUserIds'] as List<dynamic>?)?.cast<String>() ?? const [],
    coAuthorIds:
        (j['coAuthorIds'] as List<dynamic>?)?.cast<String>() ?? const [],
    commentsDisabled: j['commentsDisabled'] as bool? ?? false,
    likesHidden: j['likesHidden'] as bool? ?? false,
    updatedAt:
        DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'caption': caption,
    'items': items.map((e) => e.toMap()).toList(),
    'location': location,
    'taggedUserIds': taggedUserIds,
    'coAuthorIds': coAuthorIds,
    'commentsDisabled': commentsDisabled,
    'likesHidden': likesHidden,
    'updatedAt': updatedAt.toIso8601String(),
  };
}
