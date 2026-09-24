import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/spotify_track.dart';
import '../../../models/story.dart';
import '../../../widgets/components/components.dart';
import '../../auth/providers/auth_providers.dart';
import '../../feed/providers/feed_providers.dart';
import '../../post/presentation/spotify_picker_sheet.dart';
import '../providers/story_providers.dart';
import 'widgets/story_sticker_view.dart';

/// Story composer: pick/capture media, add interactive stickers, choose
/// audience, then post (expires in 24h).
class StoryComposerScreen extends ConsumerStatefulWidget {
  const StoryComposerScreen({
    super.key,
    this.addYoursPrompt,
    this.addYoursSourceId,
  });

  final String? addYoursPrompt;
  final String? addYoursSourceId;

  @override
  ConsumerState<StoryComposerScreen> createState() =>
      _StoryComposerScreenState();
}

class _StoryComposerScreenState extends ConsumerState<StoryComposerScreen> {
  File? _file;
  bool _isVideo = false;
  final List<StorySticker> _stickers = [];
  bool _closeFriends = false;
  bool _loading = false;
  SpotifyTrack? _track;

  Future<void> _pick({required ImageSource source, required bool video}) async {
    final picker = ImagePicker();
    final x = video
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(
            source: source,
            imageQuality: 90,
            maxWidth: 1440,
          );
    if (x != null) {
      setState(() {
        _file = File(x.path);
        _isVideo = video;
      });
    }
  }

  Future<void> _post() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null || _file == null) return;
    setState(() => _loading = true);
    try {
      final favorites = _closeFriends
          ? (ref.read(favoriteIdsProvider).valueOrNull ?? const [])
          : const <String>[];
      await ref
          .read(storyRepositoryProvider)
          .createStory(
            uid: uid,
            file: _file!,
            isVideo: _isVideo,
            stickers: _stickers,
            closeFriendsOnly: _closeFriends,
            closeFriends: favorites,
            addYoursPrompt: widget.addYoursPrompt,
            addYoursSourceId: widget.addYoursSourceId,
            musicTitle: _track?.name,
            musicArtist: _track?.artist,
            musicCoverUrl: _track?.coverUrl,
            musicPreviewUrl: _track?.previewUrl,
            musicUrl: _track?.spotifyUrl,
          );
      if (mounted) {
        showAppToast(
          context,
          tr('Đã đăng tin.', 'Story posted.'),
          type: AppToastType.success,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          tr('Đăng tin thất bại.', 'Failed to post story.'),
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_file == null) return _picker();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _isVideo
                  ? const Center(
                      child: Icon(
                        Icons.videocam_rounded,
                        color: Colors.white,
                        size: 72,
                      ),
                    )
                  : Image.file(_file!, fit: BoxFit.contain),
            ),
            // Draggable stickers
            for (var i = 0; i < _stickers.length; i++)
              _DraggableSticker(
                sticker: _stickers[i],
                onMove: (x, y) => setState(
                  () => _stickers[i] = _stickers[i].copyWith(x: x, y: y),
                ),
              ),
            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.music_note_rounded,
                        color: _track != null
                            ? AppColors.primary
                            : Colors.white,
                      ),
                      tooltip: tr('Thêm nhạc', 'Add music'),
                      onPressed: _addMusic,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.emoji_emotions_outlined,
                        color: Colors.white,
                      ),
                      tooltip: tr('Thêm sticker', 'Add sticker'),
                      onPressed: _addStickerMenu,
                    ),
                  ],
                ),
              ),
            ),
            // Selected music chip
            if (_track != null)
              Positioned(
                top: 56,
                left: AppSpacing.md,
                right: AppSpacing.md,
                child: _ComposerMusicChip(
                  track: _track!,
                  onRemove: () => setState(() => _track = null),
                ),
              ),
            // Bottom controls
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: PressScale(
                        onTap: () =>
                            setState(() => _closeFriends = !_closeFriends),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: _closeFriends
                                ? AppColors.success
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                tr('Bạn thân', 'Close friends'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: AppType.bold,
                                  fontSize: AppType.label,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    AppButton(
                      label: tr('Đăng tin', 'Share'),
                      fullWidth: false,
                      isLoading: _loading,
                      icon: Icons.send_rounded,
                      onPressed: _post,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _picker() {
    return AppScaffold(
      topBar: AppTopBar(title: tr('Tạo tin', 'Create story'), showBack: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.xxl),
            // Hero: glowing story ring.
            Center(
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.accent, AppColors.primary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      blurRadius: 36,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              tr('Chia sẻ khoảnh khắc', 'Share a moment'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppType.title,
                fontWeight: AppType.heavy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr(
                'Tin của bạn sẽ tự biến mất sau 24 giờ',
                'Your story disappears after 24 hours',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppType.subhead,
              ),
            ),
            if (widget.addYoursPrompt != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '${tr('Thử thách', 'Challenge')}: ${widget.addYoursPrompt}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: AppType.bold,
                    fontSize: AppType.label,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            _SourceTile(
              icon: Icons.photo_library_rounded,
              label: tr('Chọn ảnh/video', 'Pick photo/video'),
              subtitle: tr('Từ thư viện của bạn', 'From your library'),
              primary: true,
              onTap: () => _pick(source: ImageSource.gallery, video: false),
            ),
            const SizedBox(height: AppSpacing.md),
            _SourceTile(
              icon: Icons.photo_camera_rounded,
              label: tr('Chụp ảnh mới', 'Take a photo'),
              subtitle: tr('Dùng camera', 'Use the camera'),
              onTap: () => _pick(source: ImageSource.camera, video: false),
            ),
            const SizedBox(height: AppSpacing.md),
            _SourceTile(
              icon: Icons.videocam_rounded,
              label: tr('Chọn video', 'Pick video'),
              subtitle: tr('Từ thư viện của bạn', 'From your library'),
              onTap: () => _pick(source: ImageSource.gallery, video: true),
            ),
          ],
        ),
      ),
    );
  }

  void _addStickerMenu() {
    showAppMenu(context, [
      AppMenuAction(
        icon: Icons.poll_outlined,
        label: tr('Bình chọn (Poll)', 'Poll'),
        onTap: () => _addPoll(),
      ),
      AppMenuAction(
        icon: Icons.help_outline_rounded,
        label: tr('Câu hỏi', 'Question'),
        onTap: () => _addQuestion(),
      ),
      AppMenuAction(
        icon: Icons.quiz_outlined,
        label: tr('Quiz', 'Quiz'),
        onTap: () => _addQuiz(),
      ),
      AppMenuAction(
        icon: Icons.timer_outlined,
        label: tr('Đếm ngược', 'Countdown'),
        onTap: () => _addCountdown(),
      ),
      AppMenuAction(
        icon: Icons.tune_rounded,
        label: tr('Thanh cảm xúc', 'Emoji slider'),
        onTap: () => _addSlider(),
      ),
      AppMenuAction(
        icon: Icons.location_on_outlined,
        label: tr('Vị trí', 'Location'),
        onTap: () => _addText(StickerType.location, tr('Địa điểm', 'Place')),
      ),
      AppMenuAction(
        icon: Icons.tag_rounded,
        label: 'Hashtag',
        onTap: () => _addText(StickerType.hashtag, 'hashtag'),
      ),
      AppMenuAction(
        icon: Icons.alternate_email_rounded,
        label: tr('Nhắc tên (mention)', 'Mention'),
        onTap: () => _addText(StickerType.mention, 'username'),
      ),
      AppMenuAction(
        icon: Icons.gif_box_outlined,
        label: 'GIF / Emoji',
        onTap: () => _addText(StickerType.gif, '🎉'),
      ),
    ]);
  }

  Future<void> _addMusic() async {
    final track = await showSpotifyPicker(context);
    if (track != null && mounted) setState(() => _track = track);
  }

  void _add(StorySticker s) => setState(() => _stickers.add(s));

  Future<void> _addText(StickerType type, String label) async {
    final v = await _promptText(label);
    if (v != null && v.isNotEmpty) {
      _add(
        StorySticker(
          id: const Uuid().v4(),
          type: type,
          y: 0.4,
          data: {'text': v},
        ),
      );
    }
  }

  Future<void> _addPoll() async {
    final q = await _promptText(tr('Câu hỏi bình chọn', 'Poll question'));
    if (q == null) return;
    _add(
      StorySticker(
        id: const Uuid().v4(),
        type: StickerType.poll,
        y: 0.45,
        data: {
          'question': q,
          'options': [tr('Có', 'Yes'), tr('Không', 'No')],
        },
      ),
    );
  }

  Future<void> _addQuestion() async {
    final p = await _promptText(tr('Câu hỏi cho người xem', 'Ask a question'));
    if (p == null) return;
    _add(
      StorySticker(
        id: const Uuid().v4(),
        type: StickerType.question,
        y: 0.45,
        data: {'prompt': p},
      ),
    );
  }

  Future<void> _addQuiz() async {
    final q = await _promptText(
      tr('Câu hỏi quiz (đáp án đúng = A)', 'Quiz question (correct = A)'),
    );
    if (q == null) return;
    _add(
      StorySticker(
        id: const Uuid().v4(),
        type: StickerType.quiz,
        y: 0.45,
        data: {
          'question': q,
          'options': ['A', 'B', 'C'],
          'correctIndex': 0,
        },
      ),
    );
  }

  Future<void> _addCountdown() async {
    final t = await _promptText(
      tr('Tên đếm ngược (kết thúc sau 24h)', 'Countdown title (ends in 24h)'),
    );
    if (t == null) return;
    _add(
      StorySticker(
        id: const Uuid().v4(),
        type: StickerType.countdown,
        y: 0.4,
        data: {
          'title': t,
          'endAt': DateTime.now()
              .add(const Duration(hours: 24))
              .millisecondsSinceEpoch,
        },
      ),
    );
  }

  Future<void> _addSlider() async {
    final q = await _promptText(tr('Câu hỏi thanh cảm xúc', 'Slider question'));
    if (q == null) return;
    _add(
      StorySticker(
        id: const Uuid().v4(),
        type: StickerType.slider,
        y: 0.45,
        data: {'question': q, 'emoji': '😍'},
      ),
    );
  }

  Future<String?> _promptText(String label) {
    final c = TextEditingController();
    return showDialog<String>(
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
              AppTextField(controller: c, label: label),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: tr('Thêm', 'Add'),
                onPressed: () => Navigator.pop(dctx, c.text.trim()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraggableSticker extends StatelessWidget {
  const _DraggableSticker({required this.sticker, required this.onMove});
  final StorySticker sticker;
  final void Function(double x, double y) onMove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment(sticker.x * 2 - 1, sticker.y * 2 - 1),
          child: GestureDetector(
            onPanUpdate: (d) {
              final nx = (sticker.x + d.delta.dx / constraints.maxWidth).clamp(
                0.1,
                0.9,
              );
              final ny = (sticker.y + d.delta.dy / constraints.maxHeight).clamp(
                0.1,
                0.9,
              );
              onMove(nx, ny);
            },
            child: StoryStickerView(storyId: '', sticker: sticker),
          ),
        );
      },
    );
  }
}

/// A compact pill on the composer showing the attached track, with a remove
/// button. Playback preview happens in the story viewer.
class _ComposerMusicChip extends StatelessWidget {
  const _ComposerMusicChip({required this.track, required this.onRemove});
  final SpotifyTrack track;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.music_note_rounded, color: Colors.white, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              '${track.name} · ${track.artist}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: AppType.medium,
                fontSize: AppType.label,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              color: Colors.white70,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

/// A full-width source option row: tinted icon, label + subtitle, chevron.
/// [primary] paints the brand gradient for the recommended action.
class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : AppColors.textPrimary;
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: primary
              ? LinearGradient(
                  colors: [AppColors.primaryBright, AppColors.primary],
                )
              : null,
          color: primary ? null : AppColors.layer1,
          borderRadius: AppRadius.brLg,
          border: Border.all(
            color: primary ? Colors.transparent : AppColors.borderSubtle,
          ),
          boxShadow: primary ? AppShadows.soft : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primary
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                icon,
                color: primary ? Colors.white : AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: AppType.subhead,
                      fontWeight: AppType.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: primary
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppColors.textSecondary,
                      fontSize: AppType.label,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: primary
                  ? Colors.white.withValues(alpha: 0.9)
                  : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
