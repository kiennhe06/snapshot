import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/chat.dart';
import '../../../widgets/components/components.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/message_providers.dart';

/// Opens a sheet to forward a post or story into one of the user's chats.
/// [type] must be [MessageType.post] or [MessageType.story].
Future<void> showShareToChatSheet(
  BuildContext context, {
  required MessageType type,
  required String refId,
}) {
  return showAppSheet<void>(
    context,
    builder: (_) => _ShareSheet(type: type, refId: refId),
  );
}

class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({required this.type, required this.refId});
  final MessageType type;
  final String refId;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  final _sent = <String>{};

  Future<void> _send(Chat chat, String me) async {
    setState(() => _sent.add(chat.chatId));
    await ref
        .read(chatRepositoryProvider)
        .sendShare(
          chatId: chat.chatId,
          senderId: me,
          type: widget.type,
          refId: widget.refId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final chats = ref.watch(chatsProvider).valueOrNull ?? const [];

    return AppSheetSurface(
      title: tr('Gửi tới...', 'Send to...'),
      maxHeightFactor: 0.7,
      child: chats.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                tr('Chưa có cuộc trò chuyện nào.', 'No conversations yet.'),
                style: TextStyle(color: AppColors.textTertiary),
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              itemCount: chats.length,
              itemBuilder: (_, i) => _ChatSendRow(
                chat: chats[i],
                me: me,
                sent: _sent.contains(chats[i].chatId),
                onSend: () => _send(chats[i], me),
              ),
            ),
    );
  }
}

class _ChatSendRow extends ConsumerWidget {
  const _ChatSendRow({
    required this.chat,
    required this.me,
    required this.sent,
    required this.onSend,
  });
  final Chat chat;
  final String me;
  final bool sent;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String title;
    String? photoUrl;
    if (chat.isDm) {
      final other = ref
          .watch(userProfileProvider(chat.otherMember(me)))
          .valueOrNull;
      title = other?.username.isNotEmpty == true
          ? other!.username
          : (other?.displayName ?? '');
      photoUrl = other?.photoUrl;
    } else {
      title = chat.name ?? tr('Nhóm', 'Group');
      photoUrl = chat.photoUrl;
    }

    return AppTile(
      leading: AppAvatar(
        radius: 22,
        icon: chat.isBroadcast
            ? Icons.campaign_rounded
            : (chat.isGroup ? Icons.group_rounded : Icons.person_rounded),
        imageProvider: photoUrl != null
            ? CachedNetworkImageProvider(photoUrl)
            : null,
      ),
      title: title,
      trailing: sent
          ? Icon(Icons.check_circle_rounded, color: AppColors.success)
          : AppButton(
              label: tr('Gửi', 'Send'),
              fullWidth: false,
              height: 36,
              onPressed: onSend,
            ),
    );
  }
}
