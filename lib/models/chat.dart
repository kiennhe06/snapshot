import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatType { dm, group, broadcast }

ChatType chatTypeFrom(String? s) => ChatType.values.firstWhere(
  (e) => e.name == s,
  orElse: () => ChatType.dm,
);

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
  final DateTime lastAt;

  bool get isDm => type == ChatType.dm;
  bool get isGroup => type == ChatType.group;
  bool get isBroadcast => type == ChatType.broadcast;

  /// The other member of a DM, relative to [me].
  String otherMember(String me) =>
      memberIds.firstWhere((id) => id != me, orElse: () => me);

  factory Chat.fromMap(Map<String, dynamic> j) => Chat(
    chatId: j['chatId'] as String? ?? '',
    type: chatTypeFrom(j['type'] as String?),
    memberIds: (j['memberIds'] as List<dynamic>?)?.cast<String>() ?? const [],
    adminIds: (j['adminIds'] as List<dynamic>?)?.cast<String>() ?? const [],
    name: j['name'] as String?,
    photoUrl: j['photoUrl'] as String?,
    lastText: j['lastText'] as String?,
    lastSenderId: j['lastSenderId'] as String?,
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
  const Note({required this.uid, required this.text, required this.expiresAt});
  final String uid;
  final String text;
  final DateTime expiresAt;

  bool get isActive => DateTime.now().isBefore(expiresAt);

  factory Note.fromMap(String uid, Map<String, dynamic> j) => Note(
    uid: uid,
    text: j['text'] as String? ?? '',
    expiresAt: _toDate(j['expiresAt']),
  );

  static DateTime _toDate(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
