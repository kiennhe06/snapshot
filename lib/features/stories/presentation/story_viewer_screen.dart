import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/story.dart';
import '../../../widgets/components/components.dart';
import '../../auth/providers/auth_providers.dart';
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

  StoryTray get _currentTray => widget.trays[_tray];
  Story get _current => _currentTray.stories[_idx];

  @override
  void initState() {
    super.initState();
    _tray = widget.initialIndex;
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
    super.dispose();
  }

  void _start() {
    _markViewed();
    if (!_current.isVideo) {
      _progress
        ..reset()
        ..forward();
    } else {
      _progress.reset(); // video: no auto timer in this build
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
    } else if (!_current.isVideo) {
      _progress.forward();
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
            // Media
            if (_current.isVideo)
              AppVideo(
                url: _current.mediaUrl,
                active: true,
                fit: BoxFit.contain,
                showControls: false,
              )
            else
              CachedNetworkImage(
                imageUrl: _current.mediaUrl,
                fit: BoxFit.contain,
                placeholder: (_, _) => const ColoredBox(color: Colors.black),
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
                        CircleAvatar(
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
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            author?.username.isNotEmpty == true
                                ? author!.username
                                : (author?.displayName ?? ''),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: AppType.subhead,
                              fontWeight: AppType.bold,
                            ),
                          ),
                        ),
                        if (_current.closeFriendsOnly)
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.success,
                            size: 18,
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
                    const Icon(
                      Icons.add_circle_outline,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${tr('Thêm của bạn', 'Add yours')}: ${_current.addYoursPrompt}',
                      style: const TextStyle(
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
            IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              onPressed: () {
                _reply.clear();
                _setPaused(false);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(tr('Đã gửi.', 'Sent.'))));
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
                style: const TextStyle(
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
                style: const TextStyle(
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
