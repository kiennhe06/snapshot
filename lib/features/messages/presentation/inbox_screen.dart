import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/format.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/app_user.dart';
import '../../../models/chat.dart';
import '../../../models/spotify_track.dart';
import '../../post/presentation/spotify_picker_sheet.dart';
import '../../post/presentation/track_detail_sheet.dart';
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
    final totalUnread = (chats.valueOrNull ?? const <Chat>[])
        .fold<int>(0, (s, c) => s + c.unreadFor(me ?? ''));

    return AppScaffold(
      topBar: AppTopBar(
        showBack: true,
        titleWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('Tin nhắn', 'Messages'),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppType.headline,
                fontWeight: AppType.bold,
              ),
            ),
            if (totalUnread > 0) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryBright, AppColors.primary],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  tr('$totalUnread mới', '$totalUnread new'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppType.small,
                    fontWeight: AppType.heavy,
                  ),
                ),
              ),
            ],
          ],
        ),
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
      (_InboxFilter.channel, tr('Kênh thông báo', 'Channels')),
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
              child: AppFilterChip(
                label: label,
                selected: selected == f,
                onTap: () => onSelect(f),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: AppSectionLabel(tr('Ghi chú · 24h', 'Notes · 24h')),
        ),
        SizedBox(
          height: 116,
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
        ),
      ],
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
      label: tr('Ghi chú của bạn', 'Your note'),
      note: note,
      isMine: true,
      onTap: () => showAppSheet<void>(
        context,
        builder: (_) => _NoteComposerSheet(me: me, note: note),
      ),
    );
  }
}

/// Rich note composer matching the mockup: 60-char note, optional real track,
/// audience label and a gradient share button. Notes auto-expire after 24h.
class _NoteComposerSheet extends ConsumerStatefulWidget {
  const _NoteComposerSheet({required this.me, required this.note});
  final String me;
  final Note? note;

  @override
  ConsumerState<_NoteComposerSheet> createState() => _NoteComposerSheetState();
}

class _NoteComposerSheetState extends ConsumerState<_NoteComposerSheet> {
  late final TextEditingController _text =
      TextEditingController(text: widget.note?.text ?? '');
  SpotifyTrack? _track;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    if (n != null && n.hasMusic) {
      _track = SpotifyTrack(
        id: n.musicUrl ?? n.musicTitle!,
        name: n.musicTitle!,
        artist: n.musicArtist ?? '',
        coverUrl: n.musicCoverUrl ?? '',
        spotifyUrl: n.musicUrl ?? '',
        previewUrl: n.musicPreviewUrl,
      );
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickMusic() async {
    final t = await showSpotifyPicker(context);
    if (t != null && mounted) setState(() => _track = t);
  }

  /// Chip tap: with no song, opens the picker; with a song selected, opens its
  /// detail sheet (preview + change/remove).
  Future<void> _onMusicChipTap() async {
    if (_track == null) {
      await _pickMusic();
      return;
    }
    final action = await showTrackDetail(context, _track!);
    if (!mounted) return;
    switch (action) {
      case TrackDetailAction.change:
        await _pickMusic();
      case TrackDetailAction.remove:
        setState(() => _track = null);
      case null:
        break;
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    final repo = ref.read(chatRepositoryProvider);
    final text = _text.text.trim();
    if (text.isEmpty && _track == null) {
      await repo.clearNote(widget.me);
    } else {
      await repo.setNote(
        widget.me,
        text,
        musicTitle: _track?.name,
        musicArtist: _track?.artist,
        musicCoverUrl: _track?.coverUrl,
        musicPreviewUrl: _track?.previewUrl,
        musicUrl: _track?.spotifyUrl,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: AppSheetSurface(
        title: tr('Chia sẻ ghi chú', 'Share a note'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(
                'Ghi chú hiển thị trên đầu tin nhắn của bạn bè · 24 giờ',
                'Shown on top of your friends\' inbox · 24h',
              ),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppType.label,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Note text box — only the text + counter, so nothing overlaps it.
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.layer2,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _text,
                    maxLength: 60,
                    maxLines: 3,
                    minLines: 2,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      counterText: '',
                      hintText: tr(
                        'Bạn đang nghĩ gì? Chia sẻ cảm xúc hoặc bài hát yêu thích…',
                        'What are you thinking? Share a mood or a song…',
                      ),
                      hintStyle: TextStyle(color: AppColors.textTertiary),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_text.text.characters.length}/60',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: AppType.label,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Music sits on its own row below the note, never over the text.
            _MusicChip(track: _track, onTap: _onMusicChipTap, onRemove: () {
              setState(() => _track = null);
            }),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.group_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  tr(
                    'Chia sẻ với người bạn theo dõi',
                    'Shared with people you follow',
                  ),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppType.label,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppGradientButton(
              label: widget.note != null &&
                      _text.text.trim().isEmpty &&
                      _track == null
                  ? tr('Xoá ghi chú', 'Remove note')
                  : tr('Chia sẻ ghi chú', 'Share note'),
              loading: _busy,
              showArrow: false,
              icon: Icons.auto_awesome_rounded,
              onTap: _share,
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Add music" / selected-track pill shown on its own row below the note
/// text, so the music never overlaps what the user is typing.
class _MusicChip extends StatelessWidget {
  const _MusicChip({
    required this.track,
    required this.onTap,
    required this.onRemove,
  });

  final SpotifyTrack? track;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: PressScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.primary),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.music_note_rounded,
                size: 15,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  track == null
                      ? tr('Thêm nhạc', 'Add music')
                      : track!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: AppType.label,
                    fontWeight: AppType.bold,
                  ),
                ),
              ),
              if (track != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onRemove,
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
      note: note,
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
    required this.note,
    required this.isMine,
    required this.onTap,
  });

  final String? photoUrl;
  final String label;
  final Note? note;
  final bool isMine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasMusic = note?.hasMusic ?? false;
    final bubble = hasMusic
        ? '♪ ${note!.musicTitle}'
        : ((note?.text.isNotEmpty ?? false)
              ? note!.text
              : (isMine ? tr('Ghi chú...', 'Note...') : ''));
    // Ring: music notes get an accent ring; your own note gets the brand ring.
    final ring = hasMusic
        ? LinearGradient(colors: [AppColors.accent, AppColors.accent])
        : (isMine
              ? LinearGradient(
                  colors: [AppColors.primaryBright, AppColors.primary],
                )
              : null);

    return PressScale(
      onTap: onTap,
      child: SizedBox(
        width: 78,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: ring,
                      color: ring == null ? AppColors.layer3 : null,
                    ),
                    child: AppAvatar(
                      radius: 24,
                      imageProvider: photoUrl != null
                          ? CachedNetworkImageProvider(photoUrl!)
                          : null,
                    ),
                  ),
                ),
                // Status bubble above the avatar.
                Container(
                  constraints: const BoxConstraints(maxWidth: 76),
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
                    bubble,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppType.caption,
                      color: hasMusic ? AppColors.accent : AppColors.textPrimary,
                      fontWeight: hasMusic ? AppType.bold : AppType.regular,
                    ),
                  ),
                ),
                // "+" affordance to add/edit your own note.
                if (isMine)
                  Positioned(
                    right: 8,
                    bottom: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.layer1, width: 2),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 13,
                        color: Colors.white,
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
                        relativeTime(chat.lastAt, short: true),
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
