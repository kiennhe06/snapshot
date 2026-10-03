import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';

import '../../../models/ai_message.dart';
import '../../feed/data/interest_repository.dart';

/// Talks to Gemini (via Firebase AI Logic — no raw API key in the client) and
/// persists the "Snapshot AI" conversation plus a small, user-owned memory the
/// assistant is grounded on. The model itself is never trained; instead each
/// request is grounded on what the user taught it + their interest profile, so
/// the assistant feels like it learns and can be taught.
class AiRepository {
  AiRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Fast, inexpensive multimodal model on the free Gemini Developer API tier.
  static const _modelName = 'gemini-2.5-flash';

  CollectionReference<Map<String, dynamic>> _messagesCol(String uid) =>
      _db.collection('users').doc(uid).collection('aiMessages');

  DocumentReference<Map<String, dynamic>> _memoryDoc(String uid) =>
      _db.collection('users').doc(uid).collection('meta').doc('ai_memory');

  // ---- Conversation history --------------------------------------------------

  /// Live conversation with the assistant, oldest first.
  Stream<List<AiMessage>> watchMessages(String uid) {
    return _messagesCol(uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => AiMessage.fromMap(d.data()))
              .toList();
          list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return list;
        });
  }

  Future<void> addMessage(String uid, AiRole role, String text) {
    final ref = _messagesCol(uid).doc();
    return ref.set(
      AiMessage(
        id: ref.id,
        role: role,
        text: text,
        createdAt: DateTime.now(),
      ).toMap()..['createdAt'] = FieldValue.serverTimestamp(),
    );
  }

  /// Clears the whole conversation (keeps the learned memory).
  Future<void> clearConversation(String uid) async {
    final docs = await _messagesCol(uid).get();
    final batch = _db.batch();
    for (final d in docs.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  // ---- Memory (what the user taught it) --------------------------------------

  /// Facts the user taught the assistant, newest first.
  Stream<List<String>> watchMemory(String uid) {
    return _memoryDoc(uid).snapshots().map((d) {
      final facts = d.data()?['facts'] as List<dynamic>?;
      return facts?.cast<String>() ?? const [];
    });
  }

  Future<void> addMemory(String uid, String fact) {
    final clean = fact.trim();
    if (clean.isEmpty) return Future.value();
    return _memoryDoc(uid).set({
      'facts': FieldValue.arrayUnion([clean]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeMemory(String uid, String fact) {
    return _memoryDoc(uid).set({
      'facts': FieldValue.arrayRemove([fact]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> clearMemory(String uid) {
    return _memoryDoc(uid).set({
      'facts': <String>[],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---- Generation ------------------------------------------------------------

  /// Builds the grounding system instruction from what the assistant knows about
  /// the user: the facts they taught it + the topics they engage with.
  String _systemInstruction({
    required List<String> memory,
    required InterestProfile interests,
    String? displayName,
  }) {
    final buffer = StringBuffer()
      ..writeln(
        'Bạn là "Snapshot AI", trợ lý thân thiện bên trong Snapshot — một mạng '
        'xã hội chia sẻ ảnh và reel. Nhiệm vụ: trò chuyện tự nhiên và giúp người '
        'dùng sáng tạo nội dung (viết caption, gợi ý hashtag, viết bio, lên ý '
        'tưởng bài đăng/reel), giải đáp về cách dùng app.',
      )
      ..writeln(
        'Luôn trả lời bằng ngôn ngữ của người dùng (mặc định tiếng Việt). '
        'Ngắn gọn, ấm áp, thực tế. Dùng emoji vừa phải. Không bịa thông tin cá '
        'nhân; nếu chưa rõ thì hỏi lại một câu ngắn.',
      );
    if (displayName != null && displayName.trim().isNotEmpty) {
      buffer.writeln('Tên người dùng: ${displayName.trim()}.');
    }
    if (memory.isNotEmpty) {
      buffer
        ..writeln(
          '\nNhững điều người dùng đã DẠY bạn — hãy ghi nhớ và tôn trọng:',
        )
        ..writeAll(memory.map((f) => '- $f'), '\n');
    }
    final topTopics = _topHashtags(interests, 8);
    if (topTopics.isNotEmpty) {
      buffer.writeln(
        '\nChủ đề người dùng hay quan tâm (suy ra từ hành vi, dùng để cá nhân '
        'hoá gợi ý — KHÔNG liệt kê lại máy móc): ${topTopics.join(', ')}.',
      );
    }
    return buffer.toString();
  }

  List<String> _topHashtags(InterestProfile p, int n) {
    final entries = p.hashtags.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(n).map((e) => e.key).toList();
  }

  /// Sends [userText] to Gemini with the recent [history] and grounding, and
  /// returns the assistant's reply text. Throws on failure (caller handles it).
  Future<String> generateReply({
    required List<AiMessage> history,
    required String userText,
    required List<String> memory,
    required InterestProfile interests,
    String? displayName,
  }) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: _modelName,
      systemInstruction: Content.system(
        _systemInstruction(
          memory: memory,
          interests: interests,
          displayName: displayName,
        ),
      ),
      generationConfig: GenerationConfig(
        temperature: 0.8,
        maxOutputTokens: 1024,
      ),
    );
    // Send the last turns as context (cap to keep the request small/cheap).
    final recent = history.length > 20
        ? history.sublist(history.length - 20)
        : history;
    final chat = model.startChat(
      history: [
        for (final m in recent)
          m.isUser
              ? Content.text(m.text)
              : Content.model([TextPart(m.text)]),
      ],
    );
    final response = await chat.sendMessage(Content.text(userText));
    final text = response.text?.trim();
    if (text == null || text.isEmpty) {
      throw Exception('Empty AI response');
    }
    return text;
  }

  /// Suggests a few caption options for a new post. When [image] is given, the
  /// model looks at the photo so captions are actually about it; otherwise it
  /// works from [note] and the user's interests. Returns distinct captions.
  Future<List<String>> suggestCaptions({
    File? image,
    String? note,
    required List<String> memory,
    required InterestProfile interests,
  }) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: _modelName,
      systemInstruction: Content.system(
        '${_systemInstruction(memory: memory, interests: interests)}\n'
        'Bây giờ hãy đóng vai người viết caption Instagram.',
      ),
      generationConfig: GenerationConfig(
        temperature: 0.95,
        maxOutputTokens: 512,
      ),
    );

    final hint = (note ?? '').trim();
    final prompt = StringBuffer()
      ..writeln(
        'Viết 3 caption khác nhau cho một bài đăng mạng xã hội, bằng ngôn ngữ '
        'của người dùng (mặc định tiếng Việt).',
      )
      ..writeln(
        'Mỗi caption ngắn gọn, có cảm xúc/cá tính, kèm 2-4 hashtag phù hợp ở '
        'cuối.',
      )
      ..writeln(
        'Trả về ĐÚNG 3 dòng, mỗi dòng là một caption hoàn chỉnh. KHÔNG đánh số, '
        'KHÔNG thêm lời dẫn, KHÔNG dùng dấu gạch đầu dòng.',
      );
    if (hint.isNotEmpty) prompt.writeln('Gợi ý từ người dùng: "$hint".');

    final GenerateContentResponse response;
    if (image != null) {
      final bytes = await image.readAsBytes();
      response = await model.generateContent([
        Content.multi([
          TextPart(prompt.toString()),
          InlineDataPart(_mimeFor(image.path), bytes),
        ]),
      ]);
    } else {
      response = await model.generateContent([Content.text(prompt.toString())]);
    }

    final text = response.text?.trim() ?? '';
    final lines = text
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'^\s*(\d+[\).\-]|[-*•])\s*'), '').trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) throw Exception('Empty caption response');
    return lines.take(3).toList();
  }

  String _mimeFor(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}
