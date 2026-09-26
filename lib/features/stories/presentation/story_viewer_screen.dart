import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/motion.dart';
import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/story.dart';
import '../../../widgets/components/components.dart';
import '../../auth/providers/auth_providers.dart';
import '../../messages/providers/message_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/story_providers.dart';
import 'story_composer_screen.dart';
import 'widgets/story_sticker_view.dart';

/// Full-screen story viewer across trays with progress bars, tap-to-advance,
/// interactive stickers, "seen by" for own stories, reply, and "Add yours".
class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.trays,
    required this.initialIndex,
  });

  final List<StoryTray> trays;
  final int initialIndex;

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late int _tray;
  int _idx = 0;
  late final AnimationController _progress;
  final _reply = TextEditingController();
  final _audio = AudioPlayer();
  bool _muted = false;
  String? _playingUrl;

  StoryTray get _currentTray => widget.trays[_tray];
  Story get _current => _currentTray.stories[_idx];

  @override
  void initState() {
    super.initState();
    _tray = widget.initialIndex;
    _audio.setReleaseMode(ReleaseMode.loop); // 30s preview loops during story
    _progress =
        AnimationController(vsync: this, duration: const Duration(seconds: 5))
          ..addStatusListener((s) {
            if (s == AnimationStatus.completed) _next();
          });
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _progress.dispose();
    _reply.dispose();
    _audio.dispose();
    super.dispose();
  }

  void _start() {
    _markViewed();
    _syncMusic();
    if (!_current.isVideo) {
      _progress
        ..reset()
        ..forward();
    } else {
      _progress.reset(); // video: no auto timer in this build
    }
  }

  /// Plays the current story's 30s music preview (looping) when it changes.
  Future<void> _syncMusic() async {
    final preview = _current.musicPreviewUrl;
    if (preview == null || preview.isEmpty || _muted) {
      _playingUrl = null;
      await _audio.stop();
      return;
    }
    if (_playingUrl == preview) return; // already playing this track
    _playingUrl = preview;
    try {
      await _audio.play(UrlSource(preview));
    } catch (_) {
      _playingUrl = null;
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    if (_muted) {
      _audio.pause();
    } else {
      _playingUrl = null; // force replay of current track
      _syncMusic();
    }
  }

  void _markViewed() {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid != null && _current.authorId != uid) {
      ref.read(storyRepositoryProvider).markViewed(_current.storyId, uid);
    }
  }

  void _next() {
    if (_idx < _currentTray.stories.length - 1) {
      setState(() => _idx++);
      _start();
    } else if (_tray < widget.trays.length - 1) {
      setState(() {
        _tray++;
        _idx = 0;
      });
      _start();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _prev() {
    if (_idx > 0) {
      setState(() => _idx--);
      _start();
    } else if (_tray > 0) {
      setState(() {
        _tray--;
        _idx = 0;
      });
      _start();
    }
  }

  void _setPaused(bool v) {
    if (v) {
      _progress.stop();
      _audio.pause();
    } else {
      if (!_current.isVideo) _progress.forward();
      if (!_muted && _playingUrl != null) _audio.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final isMine = _current.authorId == myUid;
    final author = ref
        .watch(userProfileProvider(_current.authorId))
        .valueOrNull;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (d) {
          final w = MediaQuery.of(context).size.width;
          if (d.globalPosition.dx < w * 0.32) {
            _prev();
          } else {
            _next();
          }
        },
        onLongPressStart: (_) => _setPaused(true),
        onLongPressEnd: (_) => _setPaused(false),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 200) Navigator.of(context).maybePop();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media — cross-fades as the story advances (keyed by storyId).
            AnimatedSwitcher(
              duration: Motion.dur(context, AppMotion.base),
              child: _current.isVideo
                  ? AppVideo(
                      key: ValueKey(_current.storyId),
                      url: _current.mediaUrl,
                      active: true,
                      fit: BoxFit.contain,
                      showControls: false,
                    )
                  : CachedNetworkImage(
                      key: ValueKey(_current.storyId),
                      imageUrl: _current.mediaUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, _) =>
                          const ColoredBox(color: Colors.black),
                    ),
            ),

            // Stickers
            for (final s in _current.stickers)
              Align(
                alignment: Alignment(s.x * 2 - 1, s.y * 2 - 1),
                child: StoryStickerView(
                  storyId: _current.storyId,
                  sticker: s,
                  interactive: !isMine,
                  onQuestionTap: (st) => _answerQuestion(st),
                ),
              ),

            // Top: progress + header
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Column(
                  children: [
                    Row(
                      children: List.generate(_currentTray.stories.length, (i) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: _ProgressBar(
                              progress: i < _idx
                                  ? 1
                                  : (i == _idx ? _progress : null),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Hero(
                          tag: 'story-avatar-${_current.authorId}',
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.layer3,
                            backgroundImage: author?.photoUrl != null
                                ? CachedNetworkImageProvider(author!.photoUrl!)
                                : null,
                            child: author?.photoUrl == null
                                ? const Icon(
                                    Icons.person,
                                    size: 18,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            author?.username.isNotEmpty == true
                                ? author!.username
                                : (author?.displayName ?? ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: AppType.subhead,
                              fontWeight: AppType.bold,
                            ),
                          ),
                        ),
                        if (author?.isVerified == true) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: AppColors.accent,
                          ),
                        ],
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          _relTime(_current.createdAt),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: AppType.label,
                          ),
                        ),
                        const Spacer(),
                        if (_current.closeFriendsOnly)
                          Icon(
                            Icons.star_rounded,
                            color: AppColors.success,
                            size: 18,
                          ),
                        if (_current.hasMusic &&
                            (_current.musicPreviewUrl ?? '').isNotEmpty)
                          IconButton(
                            icon: Icon(
                              _muted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              color: Colors.white,
                            ),
                            tooltip: _muted
                                ? tr('Bật tiếng', 'Unmute')
                                : tr('Tắt tiếng', 'Mute'),
                            onPressed: _toggleMute,
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                    if (_current.hasMusic) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _StoryMusicChip(story: _current),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom: reply / seen / add yours
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: isMine
                      ? _SeenBar(storyId: _current.storyId)
                      : _replyBar(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return tr('${d.inMinutes} phút', '${d.inMinutes}m');
    if (d.inHours < 24) return tr('${d.inHours} giờ', '${d.inHours}h');
    return tr('${d.inDays} ngày', '${d.inDays}d');
  }

  /// Sends a reply/reaction to the story author as a real direct message.
  Future<void> _sendToAuthor(String text) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    final body = text.trim();
    if (uid == null || body.isEmpty || uid == _current.authorId) return;
    final repo = ref.read(chatRepositoryProvider);
    final chatId = await repo.openDm(uid, _current.authorId);
    await repo.sendText(chatId: chatId, senderId: uid, text: body);
    if (mounted) {
      showAppToast(context, tr('Đã gửi.', 'Sent.'), type: AppToastType.success);
    }
  }

  Widget _replyBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_current.addYoursPrompt != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PressScale(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StoryComposerScreen(
                    addYoursPrompt: _current.addYoursPrompt,
                    addYoursSourceId: _current.storyId,
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${tr('Thêm của bạn', 'Add yours')}: ${_current.addYoursPrompt}',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: AppType.bold,
                        fontSize: AppType.label,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white54),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: TextField(
                  controller: _reply,
                  style: const TextStyle(color: Colors.white),
                  onTap: () => _setPaused(true),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    hintText: tr('Gửi tin nhắn', 'Send message'),
                    hintStyle: const TextStyle(color: Colors.white54),
                  ),
                ),
              ),
            ),
            for (final e in const ['❤️', '🔥'])
              PressScale(
                onTap: () => _sendToAuthor(e),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(e, style: const TextStyle(fontSize: 26)),
                ),
              ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              onPressed: () {
                final text = _reply.text;
                _reply.clear();
                _setPaused(false);
                _sendToAuthor(text);
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _answerQuestion(StorySticker sticker) async {
    _setPaused(true);
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.xxl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.layer1,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                sticker.data['prompt']?.toString() ?? tr('Trả lời', 'Answer'),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppType.subhead,
                  fontWeight: AppType.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: controller,
                label: tr('Trả lời', 'Answer'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: tr('Gửi', 'Send'),
                onPressed: () => Navigator.pop(dctx, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid != null && controller.text.trim().isNotEmpty) {
        await ref
            .read(storyRepositoryProvider)
            .respondQuestion(
              storyId: _current.storyId,
              stickerId: sticker.id,
              uid: uid,
              text: controller.text.trim(),
            );
      }
    }
    _setPaused(false);
  }
}

/// A small pill showing the story's attached track (cover + title · artist).
class _StoryMusicChip extends StatelessWidget {
  const _StoryMusicChip({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        4,
        4,
        AppSpacing.md,
        4,
      ),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: (story.musicCoverUrl ?? '').isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: story.musicCoverUrl!,
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 28,
                    height: 28,
                    color: Colors.white24,
                    child: const Icon(
                      Icons.music_note_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              '${story.musicTitle} · ${story.musicArtist ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: AppType.medium,
                fontSize: AppType.label,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  /// 1 = filled, null = empty, AnimationController = animating.
  final Object? progress;

  @override
  Widget build(BuildContext context) {
    double value = 0;
    Widget bar(double v) => ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: LinearProgressIndicator(
        value: v,
        minHeight: 2.5,
        backgroundColor: Colors.white38,
        valueColor: const AlwaysStoppedAnimation(Colors.white),
      ),
    );
    if (progress is AnimationController) {
      return AnimatedBuilder(
        animation: progress as AnimationController,
        builder: (_, _) => bar((progress as AnimationController).value),
      );
    }
    if (progress == 1) value = 1;
    return bar(value);
  }
}

class _SeenBar extends ConsumerWidget {
  const _SeenBar({required this.storyId});
  final String storyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewers =
        ref.watch(storyViewersProvider(storyId)).valueOrNull ?? const [];
    return PressScale(
      onTap: () => _showViewers(context, viewers),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.visibility_rounded, color: Colors.white, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '${tr('Đã xem', 'Seen by')} ${viewers.length}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: AppType.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showViewers(BuildContext context, List<String> viewers) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.layer1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                '${tr('Người đã xem', 'Viewers')} (${viewers.length})',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppType.headline,
                  fontWeight: AppType.bold,
                ),
              ),
            ),
            for (final v in viewers) _ViewerRow(uid: v),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _ViewerRow extends ConsumerWidget {
  const _ViewerRow({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(userProfileProvider(uid)).valueOrNull;
    return AppTile(
      leading: AppAvatar(
        radius: 18,
        imageProvider: u?.photoUrl != null
            ? CachedNetworkImageProvider(u!.photoUrl!)
            : null,
      ),
      title: u?.username.isNotEmpty == true
          ? '@${u!.username}'
          : (u?.displayName ?? '...'),
    );
  }
}
