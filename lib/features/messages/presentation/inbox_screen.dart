import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/app_user.dart';
import '../../../models/chat.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/components/components.dart';
import '../../../widgets/empty_view.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/message_providers.dart';
import 'chat_screen.dart';
import 'new_chat_screen.dart';

/// Direct inbox: a Notes strip on top, then the conversation list.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(chatsProvider);
    final me = ref.watch(authStateProvider).valueOrNull?.uid;

    return AppScaffold(
      topBar: AppTopBar(
        title: tr('Tin nhắn', 'Messages'),
        showBack: true,
        actions: [
          AppIconButton(
            icon: Icons.edit_square,
            tooltip: tr('Tin nhắn mới', 'New message'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const NewChatScreen())),
          ),
        ],
      ),
      body: AsyncValueView<List<Chat>>(
        value: chats,
        onRetry: () => ref.invalidate(chatsProvider),
        builder: (list) => ListView(
          children: [
            if (me != null) _NotesStrip(me: me),
            const Divider(height: 1),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxxl),
                child: EmptyView(
                  message: tr(
                    'Chưa có cuộc trò chuyện nào.\nBắt đầu nhắn tin!',
                    'No conversations yet.\nStart chatting!',
                  ),
                  icon: Icons.forum_outlined,
                ),
              )
            else
              for (final c in list) _ChatRow(chat: c, me: me ?? ''),
          ],
        ),
      ),
    );
  }
}

/// Horizontal Notes row: my note first, then notes from people I follow.
class _NotesStrip extends ConsumerWidget {
  const _NotesStrip({required this.me});
  final String me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = ref.watch(followingUsersProvider).valueOrNull ?? const [];
    final myProfile = ref.watch(myProfileProvider).valueOrNull;

    return SizedBox(
      height: 104,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        children: [
          _MyNote(me: me, profile: myProfile),
          for (final u in following) _NoteAvatar(user: u),
        ],
      ),
    );
  }
}

class _MyNote extends ConsumerWidget {
  const _MyNote({required this.me, required this.profile});
  final String me;
  final AppUser? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(noteProvider(me)).valueOrNull;
    return _NoteColumn(
      photoUrl: profile?.photoUrl,
      label: tr('Ghi chú', 'Note'),
      noteText: note?.text,
      isMine: true,
      onTap: () => _editNote(context, ref, note?.text),
    );
  }

  Future<void> _editNote(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final controller = TextEditingController(text: current ?? '');
    final result = await showAppSheet<String?>(
      context,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: AppSheetSurface(
          title: tr('Chia sẻ ghi chú', 'Share a note'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: controller,
                label: tr('Ghi chú (24 giờ)', 'Note (24h)'),
                hint: tr('Bạn đang nghĩ gì?', 'What are you thinking?'),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  if (current != null)
                    Expanded(
                      child: AppButton(
                        label: tr('Xoá', 'Delete'),
                        variant: AppButtonVariant.secondary,
                        height: 48,
                        onPressed: () => Navigator.pop(sheetCtx, ''),
                      ),
                    ),
                  if (current != null) const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: tr('Chia sẻ', 'Share'),
                      height: 48,
                      onPressed: () => Navigator.pop(sheetCtx, controller.text),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null) return;
    final repo = ref.read(chatRepositoryProvider);
    if (result.trim().isEmpty) {
      await repo.clearNote(me);
    } else {
      await repo.setNote(me, result.trim());
    }
  }
}

class _NoteAvatar extends ConsumerWidget {
  const _NoteAvatar({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(noteProvider(user.uid)).valueOrNull;
    if (note == null) return const SizedBox.shrink();
    final me = ref.watch(authStateProvider).valueOrNull?.uid;
    return _NoteColumn(
      photoUrl: user.photoUrl,
      label: user.username.isNotEmpty ? user.username : user.displayName,
      noteText: note.text,
      isMine: false,
      onTap: () async {
        if (me == null) return;
        final chatId = await ref
            .read(chatRepositoryProvider)
            .openDm(me, user.uid);
        if (!context.mounted) return;
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId)));
      },
    );
  }
}

class _NoteColumn extends StatelessWidget {
  const _NoteColumn({
    required this.photoUrl,
    required this.label,
    required this.noteText,
    required this.isMine,
    required this.onTap,
  });

  final String? photoUrl;
  final String label;
  final String? noteText;
  final bool isMine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: AppAvatar(
                    radius: 26,
                    imageProvider: photoUrl != null
                        ? CachedNetworkImageProvider(photoUrl!)
                        : null,
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(maxWidth: 74),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.layer1,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: AppShadows.soft,
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Text(
                    (noteText != null && noteText!.isNotEmpty)
                        ? noteText!
                        : (isMine ? '+' : ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: AppType.caption,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppType.small,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single conversation row in the inbox list.
class _ChatRow extends ConsumerWidget {
  const _ChatRow({required this.chat, required this.me});
  final Chat chat;
  final String me;

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
          : (other?.displayName ?? tr('Người dùng', 'User'));
      photoUrl = other?.photoUrl;
    } else {
      title =
          chat.name ??
          (chat.isBroadcast ? tr('Kênh', 'Channel') : tr('Nhóm', 'Group'));
      photoUrl = chat.photoUrl;
    }

    final preview = chat.lastText ?? '';
    IconData? kindIcon;
    if (chat.isGroup) kindIcon = Icons.group_rounded;
    if (chat.isBroadcast) kindIcon = Icons.campaign_rounded;

    return AppTile(
      leading: AppAvatar(
        radius: 26,
        icon: chat.isBroadcast
            ? Icons.campaign_rounded
            : (chat.isGroup ? Icons.group_rounded : Icons.person_rounded),
        imageProvider: photoUrl != null
            ? CachedNetworkImageProvider(photoUrl)
            : null,
      ),
      title: title,
      subtitle: preview.isEmpty
          ? tr('Nhấn để trò chuyện', 'Tap to chat')
          : preview,
      trailing: kindIcon == null
          ? null
          : Icon(kindIcon, size: AppIconSize.sm, color: AppColors.textTertiary),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.chatId)),
      ),
    );
  }
}
