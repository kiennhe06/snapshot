import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/chat.dart';
import '../../../models/post.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../data/chat_repository.dart';

/// Data-layer singleton.
final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(),
);

/// Every conversation the signed-in user belongs to, newest activity first.
final chatsProvider = StreamProvider.autoDispose<List<Chat>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(chatRepositoryProvider).watchChats(uid);
});

/// Main inbox: accepted conversations that the user has not archived. Pending
/// requests waiting on the user are routed to [requestChatsProvider] instead.
final inboxChatsProvider = Provider.autoDispose<AsyncValue<List<Chat>>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
  return ref
      .watch(chatsProvider)
      .whenData(
        (list) => list
            .where((c) => !c.isRequestFor(uid) && !c.isArchivedBy(uid))
            .toList(),
      );
});

/// Message requests: conversations started by someone the user does not follow
/// back, awaiting accept/decline.
final requestChatsProvider = Provider.autoDispose<AsyncValue<List<Chat>>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
  return ref
      .watch(chatsProvider)
      .whenData((list) => list.where((c) => c.isRequestFor(uid)).toList());
});

/// Conversations the user has archived (not requests).
final archivedChatsProvider = Provider.autoDispose<AsyncValue<List<Chat>>>((
  ref,
) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
  return ref
      .watch(chatsProvider)
      .whenData(
        (list) => list
            .where((c) => c.isArchivedBy(uid) && !c.isRequestFor(uid))
            .toList(),
      );
});

/// Number of pending requests (for the inbox badge).
final requestCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(requestChatsProvider).valueOrNull?.length ?? 0;
});

/// A single conversation document.
final chatProvider = StreamProvider.autoDispose.family<Chat?, String>((
  ref,
  chatId,
) {
  return ref.watch(chatRepositoryProvider).watchChat(chatId);
});

/// Live messages for a conversation (oldest first).
final messagesProvider = StreamProvider.autoDispose
    .family<List<Message>, String>((ref, chatId) {
      return ref.watch(chatRepositoryProvider).watchMessages(chatId);
    });

/// Pinned messages for a conversation.
final pinnedMessagesProvider = StreamProvider.autoDispose
    .family<List<Message>, String>((ref, chatId) {
      return ref.watch(chatRepositoryProvider).watchPinned(chatId);
    });

/// Uids currently typing in a conversation (excluding me).
final typingProvider = StreamProvider.autoDispose.family<List<String>, String>((
  ref,
  chatId,
) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(chatRepositoryProvider).watchTyping(chatId, uid);
});

/// A user's active inbox note (null when none / expired).
final noteProvider = StreamProvider.autoDispose.family<Note?, String>((
  ref,
  uid,
) {
  return ref.watch(chatRepositoryProvider).watchNote(uid);
});

/// A shared post/story referenced by a message (for preview cards).
final sharedPostProvider = FutureProvider.autoDispose.family<Post?, String>((
  ref,
  postId,
) {
  return ref.watch(postRepositoryProvider).getPost(postId);
});
