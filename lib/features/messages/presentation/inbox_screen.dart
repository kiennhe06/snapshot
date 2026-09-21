import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

/// Inbox filter tabs, each mapping to a real conversation kind.
enum _InboxFilter { all, dm, group, channel }

/// Direct inbox: search + filters, a Notes strip, then the conversation list.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final _search = TextEditingController();
  String _query = '';
  _InboxFilter _filter = _InboxFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matchesFilter(Chat c) => switch (_filter) {
    _InboxFilter.all => true,
    _InboxFilter.dm => c.isDm,
    _InboxFilter.group => c.isGroup,
    _InboxFilter.channel => c.isBroadcast,
  };

  @override
  Widget build(BuildContext context) {
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
        builder: (list) {
          final filtered = list.where(_matchesFilter).toList();
          return ListView(
            children: [
              if (me != null) _NotesStrip(me: me),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: AppTextField(
                  controller: _search,
                  label: tr('Tìm kiếm', 'Search'),
                  hint: tr(
                    'Tìm người dùng hoặc tin nhắn…',
                    'Search people or messages…',
                  ),
                  icon: Icons.search_rounded,
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              _FilterBar(
                selected: _filter,
                onSelect: (f) => setState(() => _filter = f),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Divider(height: 1),
              if (filtered.isEmpty)
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
                for (final c in filtered)
                  _ChatRow(chat: c, me: me ?? '', query: _query),
            ],
          );
        },
      ),
    );
  }
}

/// Horizontal filter chips mapped to conversation kinds.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelect});
  final _InboxFilter selected;
  final ValueChanged<_InboxFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = <(_InboxFilter, String)>[
      (_InboxFilter.all, tr('Tất cả', 'All')),
      (_InboxFilter.dm, tr('Chat 1-1', 'DMs')),
      (_InboxFilter.group, tr('Nhóm', 'Groups')),
      (_InboxFilter.channel, tr('Kênh', 'Channels')),
    ];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          for (final (f, label) in items)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: PressScale(
                onTap: () => onSelect(f),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  decoration: BoxDecoration(
                    color: selected == f
                        ? AppColors.primary
                        : AppColors.layer1,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: selected == f
                          ? AppColors.primary
                          : AppColors.borderSubtle,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected == f
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontSize: AppType.label,
                      fontWeight: AppType.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
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
                    style: TextStyle(
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
              style: TextStyle(
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

/// A single conversation row: avatar, name + verified, time, preview
/// (typing / type-aware / group-sender-prefixed) and unread badge.
class _ChatRow extends ConsumerWidget {
  const _ChatRow({required this.chat, required this.me, this.query = ''});
  final Chat chat;
  final String me;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve display identity.
    String title;
    String? photoUrl;
    bool verified = false;
    if (chat.isDm) {
      final other = ref
          .watch(userProfileProvider(chat.otherMember(me)))
          .valueOrNull;
      title = other?.username.isNotEmpty == true
          ? other!.username
          : (other?.displayName ?? tr('Người dùng', 'User'));
      photoUrl = other?.photoUrl;
      verified = other?.isVerified ?? false;
    } else {
      title =
          chat.name ??
          (chat.isBroadcast ? tr('Kênh', 'Channel') : tr('Nhóm', 'Group'));
      photoUrl = chat.photoUrl;
    }

    // Search filter (hide non-matching rows).
    if (query.isNotEmpty) {
      final hay = '$title ${chat.lastText ?? ''}'.toLowerCase();
      if (!hay.contains(query.toLowerCase())) return const SizedBox.shrink();
    }

    final typing = ref.watch(typingProvider(chat.chatId)).valueOrNull ?? const [];
    final unread = chat.unreadFor(me);
    final hasUnread = unread > 0;

    // Group messages get a "Sender: " prefix.
    String? senderPrefix;
    if (chat.isGroup && chat.lastSenderId != null && chat.lastSenderId != me) {
      final s = ref.watch(userProfileProvider(chat.lastSenderId!)).valueOrNull;
      final name = s?.username.isNotEmpty == true ? s!.username : s?.displayName;
      if (name != null && name.isNotEmpty) senderPrefix = '$name: ';
    }

    return PressScale(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.chatId)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            AppAvatar(
              radius: 26,
              icon: chat.isBroadcast
                  ? Icons.campaign_rounded
                  : (chat.isGroup ? Icons.group_rounded : Icons.person_rounded),
              imageProvider: photoUrl != null
                  ? CachedNetworkImageProvider(photoUrl)
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: AppType.subhead,
                            fontWeight: hasUnread
                                ? AppType.heavy
                                : AppType.bold,
                          ),
                        ),
                      ),
                      if (verified) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified_rounded,
                          size: 15,
                          color: AppColors.accent,
                        ),
                      ],
                      if (chat.isBroadcast) ...[
                        const SizedBox(width: AppSpacing.xs),
                        _KindBadge(label: tr('Kênh', 'Channel')),
                      ],
                      const Spacer(),
                      Text(
                        _relTime(chat.lastAt),
                        style: TextStyle(
                          color: hasUnread
                              ? AppColors.primary
                              : AppColors.textTertiary,
                          fontSize: AppType.small,
                          fontWeight: hasUnread
                              ? AppType.bold
                              : AppType.regular,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(child: _preview(context, typing, senderPrefix)),
                      if (hasUnread) ...[
                        const SizedBox(width: AppSpacing.sm),
                        _UnreadBadge(count: unread),
                      ] else if (chat.isDm &&
                          chat.lastSenderId == me &&
                          chat.readUpToLast(chat.otherMember(me)))
                        Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.sm),
                          child: Text(
                            tr('Đã xem', 'Seen'),
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: AppType.small,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(
    BuildContext context,
    List<String> typing,
    String? senderPrefix,
  ) {
    if (typing.isNotEmpty) {
      return Text(
        tr('Đang soạn tin nhắn…', 'Typing…'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: AppType.label,
          fontStyle: FontStyle.italic,
          fontWeight: AppType.bold,
        ),
      );
    }
    final raw = chat.lastText ?? '';
    final text = raw.isEmpty
        ? tr('Nhấn để trò chuyện', 'Tap to chat')
        : '${senderPrefix ?? ''}$raw';
    final unreadForMe = chat.unreadFor(me) > 0;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: unreadForMe ? AppColors.textPrimary : AppColors.textSecondary,
        fontSize: AppType.label,
        fontWeight: unreadForMe ? AppType.bold : AppType.regular,
      ),
    );
  }
}

/// Small pink pill with the unread message count.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: AppType.small,
          fontWeight: AppType.heavy,
        ),
      ),
    );
  }
}

/// A subtle "Channel" tag next to broadcast titles.
class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.accent,
          fontSize: AppType.caption,
          fontWeight: AppType.bold,
        ),
      ),
    );
  }
}

String _relTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return tr('vừa xong', 'now');
  if (d.inMinutes < 60) return tr('${d.inMinutes} phút', '${d.inMinutes}m');
  if (d.inHours < 24) return tr('${d.inHours} giờ', '${d.inHours}h');
  if (d.inDays < 7) return tr('${d.inDays} ngày', '${d.inDays}d');
  return DateFormat('dd/MM').format(t);
}
