import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/ai_message.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/ai_repository.dart';

/// Data-layer singleton for the AI assistant.
final aiRepositoryProvider = Provider<AiRepository>((ref) => AiRepository());

/// Live "Snapshot AI" conversation for the signed-in user (oldest first).
final aiMessagesProvider = StreamProvider.autoDispose<List<AiMessage>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(aiRepositoryProvider).watchMessages(uid);
});

/// Facts the user has taught the assistant.
final aiMemoryProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(aiRepositoryProvider).watchMemory(uid);
});
