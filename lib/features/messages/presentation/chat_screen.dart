import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/chat.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/components/components.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/message_providers.dart';
import 'widgets/message_bubble.dart';

/// Full conversation view: pinned bar, message list, typing indicator and a
/// composer with text, image/video and voice-note input.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId});
  final String chatId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _recorder = AudioRecorder();

  Message? _replyTo;
  Timer? _typingTimer;
  bool _typing = false;
  bool _recording = false;
  bool _sending = false;
  DateTime? _recordStart;
  String? _me;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _typingTimer?.cancel();
    _recorder.dispose();
    if (_me != null) {
      ref
          .read(chatRepositoryProvider)
          .setTyping(chatId: widget.chatId, uid: _me!, typing: false);
    }
    super.dispose();
  }

  void _markRead() {
    final me = ref.read(authStateProvider).valueOrNull?.uid;
    if (me != null) {
      ref.read(chatRepositoryProvider).markRead(widget.chatId, me);
    }
  }

  void _onTyping(String value) {
    final me = _me;
    if (me == null) return;
    final repo = ref.read(chatRepositoryProvider);
    if (value.isNotEmpty && !_typing) {
      _typing = true;
      repo.setTyping(chatId: widget.chatId, uid: me, typing: true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _typing = false;
      repo.setTyping(chatId: widget.chatId, uid: me, typing: false);
    });
    setState(() {});
  }

  Future<void> _sendText() async {
    final text = _input.text.trim();
    final me = _me;
    if (text.isEmpty || me == null) return;
    _input.clear();
    final reply = _replyTo;
    setState(() => _replyTo = null);
    _typing = false;
    final repo = ref.read(chatRepositoryProvider);
    await repo.setTyping(chatId: widget.chatId, uid: me, typing: false);
    await repo.sendText(
      chatId: widget.chatId,
      senderId: me,
      text: text,
      replyToId: reply?.messageId,
    );
    _scrollToBottom();
  }

  Future<void> _pickMedia(bool video) async {
    final me = _me;
    if (me == null) return;
    final picker = ImagePicker();
    final x = video
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMedia(
            chatId: widget.chatId,
            senderId: me,
            file: File(x.path),
            type: video ? MessageType.video : MessageType.image,
            replyToId: _replyTo?.messageId,
          );
      if (mounted) setState(() => _replyTo = null);
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    setState(() {
      _recording = true;
      _recordStart = DateTime.now();
    });
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    final path = await _recorder.stop();
    final me = _me;
    final ms = _recordStart == null
        ? 0
        : DateTime.now().difference(_recordStart!).inMilliseconds;
    setState(() {
      _recording = false;
      _recordStart = null;
    });
    if (cancel || path == null || me == null || ms < 500) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMedia(
            chatId: widget.chatId,
            senderId: me,
            file: File(path),
            type: MessageType.voice,
            durationMs: ms,
            replyToId: _replyTo?.messageId,
          );
      if (mounted) setState(() => _replyTo = null);
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: AppMotion.base,
          curve: AppMotion.standard,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _me = ref.watch(authStateProvider).valueOrNull?.uid;
    final chat = ref.watch(chatProvider(widget.chatId)).valueOrNull;
    final messages = ref.watch(messagesProvider(widget.chatId));
    final typing =
        ref.watch(typingProvider(widget.chatId)).valueOrNull ?? const [];
    final canSend =
        chat == null ||
        !chat.isBroadcast ||
        (_me != null && chat.adminIds.contains(_me));

    return AppScaffold(
      topBar: AppTopBar(
        showBack: true,
        titleWidget: chat == null ? null : _Header(chat: chat, me: _me ?? ''),
        title: chat == null ? tr('Trò chuyện', 'Chat') : null,
      ),
      body: Column(
        children: [
          _PinnedBar(chatId: widget.chatId, me: _me ?? ''),
          Expanded(
            child: AsyncValueView<List<Message>>(
              value: messages,
              onRetry: () => ref.invalidate(messagesProvider(widget.chatId)),
              builder: (list) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _markRead(),
                );
                var lastMineId = '';
                for (final m in list) {
                  if (m.senderId == _me) lastMineId = m.messageId;
                }
                final byId = {for (final m in list) m.messageId: m};
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final m = list[i];
                    final prev = i > 0 ? list[i - 1] : null;
                    final showSender =
                        chat != null &&
                        !chat.isDm &&
                        m.senderId != _me &&
                        prev?.senderId != m.senderId;
                    final showDate =
                        prev == null ||
                        !_sameDay(prev.createdAt, m.createdAt);
                    final bubble = MessageBubble(
                      message: m,
                      chat:
                          chat ??
                          Chat(
                            chatId: widget.chatId,
                            type: ChatType.dm,
                            memberIds: const [],
                            lastAt: DateTime.now(),
                          ),
                      me: _me ?? '',
                      replyTo: m.replyToId != null ? byId[m.replyToId] : null,
                      showSender: showSender,
                      isLastMine: m.messageId == lastMineId,
                      onLongPress: () => _messageActions(m),
                      onOpenMedia: _openMedia,
                    );
                    if (!showDate) return bubble;
                    return Column(
                      children: [_DateChip(date: m.createdAt), bubble],
                    );
                  },
                );
              },
            ),
          ),
          if (typing.isNotEmpty) _TypingIndicator(uids: typing),
          if (_replyTo != null) _replyBanner(),
          if (canSend)
            _composer()
          else
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                tr(
                  'Chỉ quản trị viên mới có thể gửi.',
                  'Only admins can send.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textTertiary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _replyBanner() {
    final r = _replyTo!;
    final preview = switch (r.type) {
      MessageType.text => r.text ?? '',
      MessageType.image => '📷 ${tr('Ảnh', 'Photo')}',
      MessageType.video => '🎥 Video',
      MessageType.voice => '🎙️ ${tr('Tin nhắn thoại', 'Voice')}',
      _ => tr('Nội dung', 'Content'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.layer3,
      child: Row(
        children: [
          Icon(
            Icons.reply_rounded,
            size: AppIconSize.sm,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              tr('Trả lời: ', 'Reply: ') + preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppType.label,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _replyTo = null),
            child: Icon(
              Icons.close_rounded,
              size: AppIconSize.sm,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer() {
    if (_recording) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        color: AppColors.layer1,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _stopRecording(cancel: true),
              child: Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Icon(
              Icons.fiber_manual_record_rounded,
              color: AppColors.danger,
              size: 14,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                tr('Đang ghi âm...', 'Recording...'),
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            GestureDetector(
              onTap: () => _stopRecording(),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.primaryBright, AppColors.primary],
                  ),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: AppIconSize.md,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      color: AppColors.layer1,
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AppIconButton(
              icon: Icons.add_circle_outline_rounded,
              onTap: _sending ? null : _attachMenu,
            ),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.layer3,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: TextField(
                  controller: _input,
                  onChanged: _onTyping,
                  minLines: 1,
                  maxLines: 5,
                  cursorColor: AppColors.primary,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppType.subhead,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: tr('Nhắn tin...', 'Message...'),
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (_sending)
              SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              )
            else if (_input.text.trim().isNotEmpty)
              GestureDetector(
                onTap: _sendText,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primaryBright, AppColors.primary],
                    ),
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: AppIconSize.md,
                  ),
                ),
              )
            else
              AppIconButton(
                icon: Icons.mic_none_rounded,
                onTap: _startRecording,
              ),
          ],
        ),
      ),
    );
  }

  void _attachMenu() {
    showAppMenu(context, [
      AppMenuAction(
        icon: Icons.photo_outlined,
        label: tr('Ảnh', 'Photo'),
        onTap: () => _pickMedia(false),
      ),
      AppMenuAction(
        icon: Icons.videocam_outlined,
        label: tr('Video', 'Video'),
        onTap: () => _pickMedia(true),
      ),
    ]);
  }

  void _openMedia(String url, bool isVideo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: isVideo
                ? AppVideo(url: url, active: true)
                : InteractiveViewer(child: CachedNetworkImage(imageUrl: url)),
          ),
        ),
      ),
    );
  }

  void _messageActions(Message m) {
    final me = _me;
    if (me == null || m.deleted) return;
    showAppSheet<void>(
      context,
      builder: (sheetCtx) => AppSheetSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final e in const ['❤️', '😂', '😮', '😢', '👍', '🔥'])
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      ref
                          .read(chatRepositoryProvider)
                          .react(
                            chatId: widget.chatId,
                            messageId: m.messageId,
                            uid: me,
                            emoji: e,
                          );
                    },
                    child: Text(e, style: const TextStyle(fontSize: 28)),
                  ),
              ],
            ),
            const Divider(height: AppSpacing.xl),
            _actionRow(
              sheetCtx,
              Icons.reply_rounded,
              tr('Trả lời', 'Reply'),
              () => setState(() => _replyTo = m),
            ),
            _actionRow(
              sheetCtx,
              m.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
              m.pinned ? tr('Bỏ ghim', 'Unpin') : tr('Ghim', 'Pin'),
              () => ref
                  .read(chatRepositoryProvider)
                  .setPinned(
                    chatId: widget.chatId,
                    messageId: m.messageId,
                    pinned: !m.pinned,
                  ),
            ),
            if (m.senderId == me)
              _actionRow(
                sheetCtx,
                Icons.block_rounded,
                tr('Thu hồi', 'Unsend'),
                () => ref
                    .read(chatRepositoryProvider)
                    .unsend(chatId: widget.chatId, messageId: m.messageId),
                destructive: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionRow(
    BuildContext sheetCtx,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool destructive = false,
  }) {
    final color = destructive ? AppColors.danger : AppColors.textPrimary;
    return PressScale(
      onTap: () {
        Navigator.pop(sheetCtx);
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: AppIconSize.md,
              color: destructive ? AppColors.danger : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: AppType.subhead,
                fontWeight: AppType.medium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chat header: avatar + name (+ typing state for DMs).
class _Header extends ConsumerWidget {
  const _Header({required this.chat, required this.me});
  final Chat chat;
  final String me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String title;
    String? photoUrl;
    String? sub;
    if (chat.isDm) {
      final other = ref
          .watch(userProfileProvider(chat.otherMember(me)))
          .valueOrNull;
      title = other?.username.isNotEmpty == true
          ? other!.username
          : (other?.displayName ?? '');
      photoUrl = other?.photoUrl;
    } else {
      title =
          chat.name ??
          (chat.isBroadcast ? tr('Kênh', 'Channel') : tr('Nhóm', 'Group'));
      photoUrl = chat.photoUrl;
      sub = tr(
        '${chat.memberIds.length} thành viên',
        '${chat.memberIds.length} members',
      );
    }
    final typing =
        ref.watch(typingProvider(chat.chatId)).valueOrNull ?? const [];
    if (typing.isNotEmpty) sub = tr('đang gõ...', 'typing...');

    return Row(
      children: [
        AppAvatar(
          radius: 18,
          icon: chat.isBroadcast
              ? Icons.campaign_rounded
              : (chat.isGroup ? Icons.group_rounded : Icons.person_rounded),
          imageProvider: photoUrl != null
              ? CachedNetworkImageProvider(photoUrl)
              : null,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppType.headline,
                  fontWeight: AppType.bold,
                ),
              ),
              if (sub != null)
                Text(
                  sub,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: AppType.small,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PinnedBar extends ConsumerWidget {
  const _PinnedBar({required this.chatId, required this.me});
  final String chatId;
  final String me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinned =
        ref.watch(pinnedMessagesProvider(chatId)).valueOrNull ?? const [];
    if (pinned.isEmpty) return const SizedBox.shrink();
    final top = pinned.first;
    final preview = switch (top.type) {
      MessageType.text => top.text ?? '',
      MessageType.image => '📷 ${tr('Ảnh', 'Photo')}',
      MessageType.video => '🎥 Video',
      MessageType.voice => '🎙️ ${tr('Tin nhắn thoại', 'Voice')}',
      _ => tr('Nội dung', 'Content'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.layer3,
      child: Row(
        children: [
          Icon(
            Icons.push_pin_rounded,
            size: AppIconSize.sm,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppType.label,
              ),
            ),
          ),
          if (pinned.length > 1)
            Text(
              '+${pinned.length - 1}',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: AppType.small,
              ),
            ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends ConsumerWidget {
  const _TypingIndicator({required this.uids});
  final List<String> uids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Name the first typer (e.g. "Hoàng Minh đang gõ…").
    String label = tr('đang gõ…', 'typing…');
    if (uids.isNotEmpty) {
      final u = ref.watch(userProfileProvider(uids.first)).valueOrNull;
      final name = u?.username.isNotEmpty == true ? u!.username : u?.displayName;
      if (name != null && name.isNotEmpty) {
        label = uids.length > 1
            ? tr('$name +${uids.length - 1} đang gõ…', '$name +${uids.length - 1} typing…')
            : tr('$name đang gõ…', '$name is typing…');
      }
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(
          left: AppSpacing.lg,
          bottom: AppSpacing.sm,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.layer2,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _TypingDots(),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppType.label,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three animated dots for the typing indicator.
class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_c.value + i / 3) % 1.0;
            final opacity = 0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: opacity),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Centered date pill separating messages by day.
class _DateChip extends StatelessWidget {
  const _DateChip({required this.date});
  final DateTime date;

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(date.year, date.month, date.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return tr('Hôm nay', 'Today');
    if (diff == 1) return tr('Hôm qua', 'Yesterday');
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: AppColors.layer2,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          _label(),
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppType.small,
            fontWeight: AppType.medium,
          ),
        ),
      ),
    );
  }
}
