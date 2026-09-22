import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatType { dm, group, broadcast }

ChatType chatTypeFrom(String? s) =>
    ChatType.values.firstWhere((e) => e.name == s, orElse: () => ChatType.dm);

enum MessageType { text, image, video, voice, post, story }

MessageType messageTypeFrom(String? s) => MessageType.values.firstWhere(
  (e) => e.name == s,
  orElse: () => MessageType.text,
);

/// A conversation: `chats/{chatId}`.
class Chat {
  const Chat({
    required this.chatId,
    required this.type,
    required this.memberIds,
    this.adminIds = const [],
    this.name,
    this.photoUrl,
    this.lastText,
    this.lastSenderId,
    this.lastType,
    this.unread = const {},
    this.reads = const {},
    required this.lastAt,
  });

  final String chatId;
  final ChatType type;
  final List<String> memberIds;
  final List<String> adminIds;
  final String? name;
  final String? photoUrl;
  final String? lastText;
  final String? lastSenderId;

  /// Type name of the last message ('text' | 'image' | 'video' | 'voice' | ...).
  final String? lastType;

  /// Per-user unread message counts, keyed by uid.
  final Map<String, int> unread;

  /// Per-user last-read timestamps, keyed by uid.
  final Map<String, DateTime> reads;
  final DateTime lastAt;

  bool get isDm => type == ChatType.dm;
  bool get isGroup => type == ChatType.group;
  bool get isBroadcast => type == ChatType.broadcast;

  /// The other member of a DM, relative to [me].
  String otherMember(String me) =>
      memberIds.firstWhere((id) => id != me, orElse: () => me);

  int unreadFor(String uid) => unread[uid] ?? 0;

  /// True when [uid] (the DM partner) has read up to the last message.
  bool readUpToLast(String uid) {
    final at = reads[uid];
    return at != null && !at.isBefore(lastAt);
  }

  factory Chat.fromMap(Map<String, dynamic> j) => Chat(
    chatId: j['chatId'] as String? ?? '',
    type: chatTypeFrom(j['type'] as String?),
    memberIds: (j['memberIds'] as List<dynamic>?)?.cast<String>() ?? const [],
    adminIds: (j['adminIds'] as List<dynamic>?)?.cast<String>() ?? const [],
    name: j['name'] as String?,
    photoUrl: j['photoUrl'] as String?,
    lastText: j['lastText'] as String?,
    lastSenderId: j['lastSenderId'] as String?,
    lastType: j['lastType'] as String?,
    unread: ((j['unread'] as Map<dynamic, dynamic>?) ?? const {}).map(
      (k, v) => MapEntry(k as String, (v as num?)?.toInt() ?? 0),
    ),
    reads: ((j['reads'] as Map<dynamic, dynamic>?) ?? const {}).map(
      (k, v) => MapEntry(k as String, _toDate(v)),
    ),
    lastAt: _toDate(j['lastAt']),
  );

  Map<String, dynamic> toMap() => {
    'chatId': chatId,
    'type': type.name,
    'memberIds': memberIds,
    'adminIds': adminIds,
    'name': name,
    'photoUrl': photoUrl,
    'lastText': lastText,
    'lastSenderId': lastSenderId,
    'lastType': lastType,
    'lastAt': Timestamp.fromDate(lastAt),
  };

  static DateTime _toDate(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.now();
  }
}

/// A message: `chats/{chatId}/messages/{messageId}`.
class Message {
  const Message({
    required this.messageId,
    required this.senderId,
    required this.type,
    this.text,
    this.mediaUrl,
    this.durationMs = 0,
    this.refId,
    this.replyToId,
    this.reactions = const {},
    this.pinned = false,
    this.deleted = false,
    this.readBy = const [],
    required this.createdAt,
  });

  final String messageId;
  final String senderId;
  final MessageType type;
  final String? text;
  final String? mediaUrl;
  final int durationMs;

  /// Referenced post/story id for shared content.
  final String? refId;
  final String? replyToId;
  final Map<String, String> reactions;
  final bool pinned;
  final bool deleted;
  final List<String> readBy;
  final DateTime createdAt;

  factory Message.fromMap(Map<String, dynamic> j) => Message(
    messageId: j['messageId'] as String? ?? '',
    senderId: j['senderId'] as String? ?? '',
    type: messageTypeFrom(j['type'] as String?),
    text: j['text'] as String?,
    mediaUrl: j['mediaUrl'] as String?,
    durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
    refId: j['refId'] as String?,
    replyToId: j['replyToId'] as String?,
    reactions:
        (j['reactions'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v.toString()),
        ) ??
        const {},
    pinned: j['pinned'] as bool? ?? false,
    deleted: j['deleted'] as bool? ?? false,
    readBy: (j['readBy'] as List<dynamic>?)?.cast<String>() ?? const [],
    createdAt: _toDate(j['createdAt']),
  );

  Map<String, dynamic> toMap() => {
    'messageId': messageId,
    'senderId': senderId,
    'type': type.name,
    'text': text,
    'mediaUrl': mediaUrl,
    'durationMs': durationMs,
    'refId': refId,
    'replyToId': replyToId,
    'reactions': reactions,
    'pinned': pinned,
    'deleted': deleted,
    'readBy': readBy,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  static DateTime _toDate(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.now();
  }
}

/// A short note shown at the top of the inbox: `users/{uid}/meta/note`.
class Note {
  const Note({
    required this.uid,
    required this.text,
    required this.expiresAt,
    this.musicTitle,
    this.musicArtist,
    this.musicCoverUrl,
    this.musicPreviewUrl,
    this.musicUrl,
  });
  final String uid;
  final String text;
  final DateTime expiresAt;

  /// Optional attached track (iTunes), shown as "♫ title" on the note.
  final String? musicTitle;
  final String? musicArtist;
  final String? musicCoverUrl;
  final String? musicPreviewUrl;
  final String? musicUrl;

  bool get isActive => DateTime.now().isBefore(expiresAt);
  bool get hasMusic => (musicTitle ?? '').isNotEmpty;

  factory Note.fromMap(String uid, Map<String, dynamic> j) => Note(
    uid: uid,
    text: j['text'] as String? ?? '',
    expiresAt: _toDate(j['expiresAt']),
    musicTitle: j['musicTitle'] as String?,
    musicArtist: j['musicArtist'] as String?,
    musicCoverUrl: j['musicCoverUrl'] as String?,
    musicPreviewUrl: j['musicPreviewUrl'] as String?,
    musicUrl: j['musicUrl'] as String?,
  );

  static DateTime _toDate(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
