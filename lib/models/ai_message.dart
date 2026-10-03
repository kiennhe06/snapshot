import 'package:cloud_firestore/cloud_firestore.dart';

/// Who sent a message in the AI assistant conversation.
enum AiRole { user, model }

AiRole aiRoleFrom(String? s) =>
    s == 'model' ? AiRole.model : AiRole.user;

/// One turn in the "Snapshot AI" conversation: `users/{uid}/aiMessages/{id}`.
class AiMessage {
  const AiMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final AiRole role;
  final String text;
  final DateTime createdAt;

  bool get isUser => role == AiRole.user;

  factory AiMessage.fromMap(Map<String, dynamic> j) => AiMessage(
    id: j['id'] as String? ?? '',
    role: aiRoleFrom(j['role'] as String?),
    text: j['text'] as String? ?? '',
    createdAt: _toDate(j['createdAt']),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'role': role.name,
    'text': text,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  static DateTime _toDate(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.now();
  }
}
