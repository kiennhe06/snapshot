import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/storage_service.dart';
import '../../../models/chat.dart';

/// All Firestore reads/writes for Direct messages: conversations (1-1, group,
/// broadcast), messages (text/image/video/voice/post/story), reactions, reply,
/// pin, unsend, read receipts, typing indicators and inbox Notes.
class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore, StorageService? storage})
    : _db = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? StorageService();

  final FirebaseFirestore _db;
  final StorageService _storage;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');

  CollectionReference<Map<String, dynamic>> _messages(String chatId) =>
      _chats.doc(chatId).collection('messages');

  // ---- Conversations ---------------------------------------------------------

  /// Deterministic id for a 1-1 chat so both users resolve the same document.
  String _dmId(String a, String b) {
    final pair = [a, b]..sort();
    return 'dm_${pair[0]}_${pair[1]}';
  }

  /// Finds (or creates) the 1-1 chat between [me] and [other]; returns its id.
  Future<String> openDm(String me, String other) async {
    final id = _dmId(me, other);
    final ref = _chats.doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set(
        Chat(
          chatId: id,
          type: ChatType.dm,
          memberIds: [me, other],
          lastAt: DateTime.now(),
        ).toMap()..['lastAt'] = FieldValue.serverTimestamp(),
      );
    }
    return id;
  }

  /// Creates a group chat with [me] as the only admin; returns its id.
  Future<String> createGroup({
    required String me,
    required List<String> memberIds,
    required String name,
    String? photoUrl,
  }) async {
    final ref = _chats.doc();
    final members = {me, ...memberIds}.toList();
    await ref.set(
      Chat(
        chatId: ref.id,
        type: ChatType.group,
        memberIds: members,
        adminIds: [me],
        name: name,
        photoUrl: photoUrl,
        lastAt: DateTime.now(),
      ).toMap()..['lastAt'] = FieldValue.serverTimestamp(),
    );
    return ref.id;
  }

  /// Creates a broadcast channel owned by [me]; subscribers are [memberIds].
  Future<String> createBroadcast({
    required String me,
    required List<String> memberIds,
    required String name,
    String? photoUrl,
  }) async {
    final ref = _chats.doc();
    final members = {me, ...memberIds}.toList();
    await ref.set(
      Chat(
        chatId: ref.id,
        type: ChatType.broadcast,
        memberIds: members,
        adminIds: [me],
        name: name,
        photoUrl: photoUrl,
        lastAt: DateTime.now(),
      ).toMap()..['lastAt'] = FieldValue.serverTimestamp(),
    );
    return ref.id;
  }

  /// Inbox: chats that contain [uid], newest activity first.
  Stream<List<Chat>> watchChats(String uid) {
    return _chats
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => Chat.fromMap(d.data())).toList();
          list.sort((a, b) => b.lastAt.compareTo(a.lastAt));
          return list;
        });
  }

  Stream<Chat?> watchChat(String chatId) {
    return _chats.doc(chatId).snapshots().map(
      (d) => d.exists ? Chat.fromMap(d.data()!) : null,
    );
  }

  // ---- Messages --------------------------------------------------------------

  /// Live message list for a chat, oldest first.
  Stream<List<Message>> watchMessages(String chatId, {int limit = 100}) {
    return _messages(chatId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => Message.fromMap(d.data())).toList();
          list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return list;
        });
  }

  /// Pinned messages of a chat (usually a handful).
  Stream<List<Message>> watchPinned(String chatId) {
    return _messages(chatId)
        .where('pinned', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => Message.fromMap(d.data())).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Writes a message and updates the parent chat's last-activity summary.
  Future<void> _send(
    String chatId,
    String senderId,
    Message Function(String id) build,
    String preview,
  ) async {
    final ref = _messages(chatId).doc();
    final msg = build(ref.id);
    final batch = _db.batch();
    batch.set(ref, msg.toMap()..['createdAt'] = FieldValue.serverTimestamp());
    batch.update(_chats.doc(chatId), {
      'lastText': preview,
      'lastSenderId': senderId,
      'lastAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> sendText({
    required String chatId,
    required String senderId,
    required String text,
    String? replyToId,
  }) {
    return _send(
      chatId,
      senderId,
      (id) => Message(
        messageId: id,
        senderId: senderId,
        type: MessageType.text,
        text: text,
        replyToId: replyToId,
        readBy: [senderId],
        createdAt: DateTime.now(),
      ),
      text,
    );
  }

  /// Sends an image/video/voice attachment (uploaded to Cloudinary first).
  Future<void> sendMedia({
    required String chatId,
    required String senderId,
    required File file,
    required MessageType type,
    int durationMs = 0,
    String? replyToId,
  }) async {
    final isVideo = type == MessageType.video || type == MessageType.voice;
    final url = await _storage.uploadChatMedia(
      chatId: chatId,
      file: file,
      isVideo: isVideo,
    );
    final preview = switch (type) {
      MessageType.image => '📷 Ảnh',
      MessageType.video => '🎥 Video',
      MessageType.voice => '🎙️ Tin nhắn thoại',
      _ => '',
    };
    await _send(
      chatId,
      senderId,
      (id) => Message(
        messageId: id,
        senderId: senderId,
        type: type,
        mediaUrl: url,
        durationMs: durationMs,
        replyToId: replyToId,
        readBy: [senderId],
        createdAt: DateTime.now(),
      ),
      preview,
    );
  }

  /// Shares a post or a story into the chat by reference id.
  Future<void> sendShare({
    required String chatId,
    required String senderId,
    required MessageType type,
    required String refId,
    String? text,
  }) {
    final preview = type == MessageType.story ? '📸 Story' : '🖼️ Bài viết';
    return _send(
      chatId,
      senderId,
      (id) => Message(
        messageId: id,
        senderId: senderId,
        type: type,
        refId: refId,
        text: text,
        readBy: [senderId],
        createdAt: DateTime.now(),
      ),
      preview,
    );
  }

  // ---- Message actions -------------------------------------------------------

  /// Toggles the current user's reaction (one emoji per user).
  Future<void> react({
    required String chatId,
    required String messageId,
    required String uid,
    required String emoji,
  }) async {
    final ref = _messages(chatId).doc(messageId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final reactions = Map<String, dynamic>.from(
        (snap.data()?['reactions'] as Map<String, dynamic>?) ?? {},
      );
      if (reactions[uid] == emoji) {
        reactions.remove(uid);
      } else {
        reactions[uid] = emoji;
      }
      tx.update(ref, {'reactions': reactions});
    });
  }

  Future<void> setPinned({
    required String chatId,
    required String messageId,
    required bool pinned,
  }) {
    return _messages(chatId).doc(messageId).update({'pinned': pinned});
  }

  /// Unsends a message: keeps the doc but clears content and marks deleted.
  Future<void> unsend({required String chatId, required String messageId}) {
    return _messages(chatId).doc(messageId).update({
      'deleted': true,
      'text': null,
      'mediaUrl': null,
      'refId': null,
      'reactions': <String, String>{},
      'pinned': false,
    });
  }

  /// Marks every message in a chat as read by [uid] (adds uid to readBy).
  Future<void> markRead(String chatId, String uid) async {
    final unread = await _messages(chatId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .get();
    final batch = _db.batch();
    for (final d in unread.docs) {
      final readBy = (d.data()['readBy'] as List<dynamic>?)?.cast<String>() ??
          const [];
      if (!readBy.contains(uid)) {
        batch.update(d.reference, {
          'readBy': FieldValue.arrayUnion([uid]),
        });
      }
    }
    await batch.commit();
  }

  // ---- Typing indicator ------------------------------------------------------

  Future<void> setTyping({
    required String chatId,
    required String uid,
    required bool typing,
  }) {
    final ref = _chats.doc(chatId).collection('typing').doc(uid);
    return typing
        ? ref.set({'at': FieldValue.serverTimestamp()})
        : ref.delete();
  }

  /// Uids currently typing (a heartbeat newer than 6s), excluding [me].
  Stream<List<String>> watchTyping(String chatId, String me) {
    return _chats.doc(chatId).collection('typing').snapshots().map((snap) {
      final now = DateTime.now();
      return snap.docs
          .where((d) {
            if (d.id == me) return false;
            final at = (d.data()['at'] as Timestamp?)?.toDate();
            return at != null && now.difference(at).inSeconds < 6;
          })
          .map((d) => d.id)
          .toList();
    });
  }

  // ---- Notes -----------------------------------------------------------------

  /// Sets the current user's inbox note (auto-expires after 24h).
  Future<void> setNote(String uid, String text) {
    return _db.collection('users').doc(uid).collection('meta').doc('note').set({
      'text': text,
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24)),
      ),
    });
  }

  Future<void> clearNote(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc('note')
        .delete();
  }

  Stream<Note?> watchNote(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc('note')
        .snapshots()
        .map((d) {
          if (!d.exists) return null;
          final note = Note.fromMap(uid, d.data()!);
          return note.isActive ? note : null;
        });
  }
}
