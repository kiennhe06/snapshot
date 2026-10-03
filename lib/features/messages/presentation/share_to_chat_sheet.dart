import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/app_user.dart';
import '../../../models/chat.dart';
import '../../../widgets/components/components.dart';
import '../../auth/providers/auth_providers.dart';
import '../../explore/providers/search_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/message_providers.dart';

/// Opens a sheet to forward a post or story. You can send it to an existing
/// conversation or to anyone you can find by name — a DM is created on the fly.
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
  final _search = TextEditingController();
  // Keyed by chatId (existing chats) or 'u:<uid>' (people) once sent.
  final _sent = <String>{};
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _sendToChat(String chatId, String me, String sentKey) async {
    setState(() => _sent.add(sentKey));
    await ref
        .read(chatRepositoryProvider)
        .sendShare(
          chatId: chatId,
          senderId: me,
          type: widget.type,
          refId: widget.refId,
        );
  }

  /// Opens (or creates) the DM with [uid], then forwards into it.
  Future<void> _sendToUser(String uid, String me) async {
    final repo = ref.read(chatRepositoryProvider);
    final chatId = await repo.openDm(me, uid);
    await _sendToChat(chatId, me, 'u:$uid');
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final chats = ref.watch(chatsProvider).valueOrNull ?? const <Chat>[];
    final qq = _query.trim().toLowerCase();

    // Existing conversations matching the query (by display name resolved per row).
    final chatRows = chats.where((c) => !c.pending).toList();

    // People to start a fresh DM: search results when typing, else people you
    // follow.
    final List<AppUser> people = qq.isEmpty
        ? (ref.watch(followingUsersProvider).valueOrNull ?? const [])
        : (ref.watch(userSearchProvider(_query.trim())).valueOrNull ?? const []);
    // Drop myself and anyone already covered by a 1-1 chat row.
    final dmPartnerIds = {
      for (final c in chatRows)
        if (c.isDm) c.otherMember(me),
    };
    final peopleRows = people
        .where((u) => u.uid != me && !dmPartnerIds.contains(u.uid))
        .toList();

    return AppSheetSurface(
      title: tr('Gửi tới...', 'Send to...'),
      maxHeightFactor: 0.75,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            controller: _search,
            label: tr('Tìm kiếm', 'Search'),
            hint: tr('Tìm người để gửi...', 'Search people to send to...'),
            icon: Icons.search_rounded,
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: (chatRows.isEmpty && peopleRows.isEmpty)
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      qq.isEmpty
                          ? tr(
                              'Hãy theo dõi ai đó hoặc tìm theo tên để gửi.',
                              'Follow someone or search a name to send to.',
                            )
                          : tr('Không tìm thấy người dùng.', 'No people found.'),
                      style: TextStyle(color: AppColors.textTertiary),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      if (chatRows.isNotEmpty && qq.isEmpty)
                        _SectionLabel(
                          tr('Trò chuyện gần đây', 'Recent chats'),
                        ),
                      if (qq.isEmpty)
                        for (final c in chatRows)
                          _ChatSendRow(
                            chat: c,
                            me: me,
                            sent: _sent.contains(c.chatId),
                            onSend: () => _sendToChat(c.chatId, me, c.chatId),
                          ),
                      if (peopleRows.isNotEmpty)
                        _SectionLabel(tr('Mọi người', 'People')),
                      for (final u in peopleRows)
                        _UserSendRow(
                          user: u,
                          sent: _sent.contains('u:${u.uid}'),
                          onSend: () => _sendToUser(u.uid, me),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xs,
      AppSpacing.sm,
      AppSpacing.xs,
      AppSpacing.xs,
    ),
    child: AppSectionLabel(text),
  );
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
        icon: chat.isGroup ? Icons.group_rounded : Icons.person_rounded,
        imageProvider: photoUrl != null
            ? CachedNetworkImageProvider(photoUrl)
            : null,
      ),
      title: title,
      trailing: _SendTrailing(sent: sent, onSend: onSend),
    );
  }
}

class _UserSendRow extends StatelessWidget {
  const _UserSendRow({
    required this.user,
    required this.sent,
    required this.onSend,
  });
  final AppUser user;
  final bool sent;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return AppTile(
      leading: AppAvatar(
        radius: 22,
        imageProvider: user.photoUrl != null
            ? CachedNetworkImageProvider(user.photoUrl!)
            : null,
      ),
      title: user.username.isNotEmpty ? user.username : user.displayName,
      subtitle: user.displayName,
      trailing: _SendTrailing(sent: sent, onSend: onSend),
    );
  }
}

class _SendTrailing extends StatelessWidget {
  const _SendTrailing({required this.sent, required this.onSend});
  final bool sent;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return sent
        ? Icon(Icons.check_circle_rounded, color: AppColors.success)
        : AppButton(
            label: tr('Gửi', 'Send'),
            fullWidth: false,
            height: 36,
            onPressed: onSend,
          );
  }
}
