import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
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

  // In-app gallery grid state.
  List<AssetEntity> _assets = [];
  bool _loadingAssets = true;
  PermissionState? _perm;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  /// Reads recent photos/videos from the device so the Create-story screen can
  /// show them as an in-app grid (like Instagram/Facebook) instead of bouncing
  /// to the system picker.
  Future<void> _loadAssets() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;
    _perm = ps;
    if (ps.isAuth || ps.hasAccess) {
      final albums = await PhotoManager.getAssetPathList(
        onlyAll: true,
        type: RequestType.common,
      );
      if (albums.isNotEmpty) {
        final recent = await albums.first.getAssetListPaged(page: 0, size: 90);
        if (mounted) setState(() => _assets = recent);
      }
    }
    if (mounted) setState(() => _loadingAssets = false);
  }

  Future<void> _useAsset(AssetEntity asset) async {
    final f = await asset.file;
    if (f != null && mounted) {
      setState(() {
        _file = f;
        _isVideo = asset.type == AssetType.video;
      });
    }
  }

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
                      // Return to the gallery grid to pick a different item
                      // instead of leaving the composer entirely.
                      onPressed: () => setState(() {
                        _file = null;
                        _stickers.clear();
                        _track = null;
                      }),
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
      topBar: AppTopBar(
        title: tr('Tạo tin', 'Create story'),
        showBack: true,
        actions: [
          AppIconButton(
            icon: Icons.photo_camera_rounded,
            tooltip: tr('Chụp ảnh', 'Take a photo'),
            onTap: () => _pick(source: ImageSource.camera, video: false),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: _loadingAssets
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: AppIconSize.sm,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.addYoursPrompt != null
                              ? '${tr('Thử thách', 'Challenge')}: ${widget.addYoursPrompt}'
                              : tr(
                                  'Tin của bạn biến mất sau 24 giờ',
                                  'Your story disappears after 24 hours',
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.label.copyWith(
                            color: widget.addYoursPrompt != null
                                ? AppColors.primary
                                : AppColors.textTertiary,
                            fontWeight: widget.addYoursPrompt != null
                                ? AppType.bold
                                : AppType.regular,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _galleryBody()),
              ],
            ),
    );
  }

  Widget _galleryBody() {
    final ps = _perm;
    if (ps != null && !ps.isAuth && !ps.hasAccess) {
      return _permissionDenied();
    }
    return Column(
      children: [
        if (ps != null && !ps.isAuth && ps.hasAccess) _limitedBanner(),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
            ),
            itemCount: _assets.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) return _cameraTile();
              final asset = _assets[i - 1];
              return _AssetThumb(
                key: ValueKey(asset.id),
                asset: asset,
                onTap: () => _useAsset(asset),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _cameraTile() {
    return PressScale(
      onTap: () => _pick(source: ImageSource.camera, video: false),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryBright, AppColors.primary],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.photo_camera_rounded,
              color: Colors.white,
              size: 30,
            ),
            const SizedBox(height: 6),
            Text(
              tr('Camera', 'Camera'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: AppType.label,
                fontWeight: AppType.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _limitedBanner() {
    return Container(
      width: double.infinity,
      color: AppColors.layer2,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tr(
                'Chỉ một số ảnh được chia sẻ với ứng dụng.',
                'Only some photos are shared with the app.',
              ),
              style: AppText.label.copyWith(color: AppColors.textSecondary),
            ),
          ),
          PressScale(
            onTap: () async {
              await PhotoManager.presentLimited();
              _setLoadingAndReload();
            },
            child: Text(
              tr('Quản lý', 'Manage'),
              style: AppText.label.copyWith(
                color: AppColors.primary,
                fontWeight: AppType.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _permissionDenied() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            tr(
              'Cho phép truy cập ảnh để chọn\nảnh/video ngay trong ứng dụng.',
              'Allow photo access to pick media\nright inside the app.',
            ),
            textAlign: TextAlign.center,
            style: AppText.h3.copyWith(
              color: AppColors.textSecondary,
              fontWeight: AppType.regular,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: tr('Mở cài đặt', 'Open settings'),
            fullWidth: false,
            onPressed: () => PhotoManager.openSetting(),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: tr('Chọn từ thư viện', 'Pick from library'),
            variant: AppButtonVariant.ghost,
            fullWidth: false,
            onPressed: () => _pick(source: ImageSource.gallery, video: false),
          ),
        ],
      ),
    );
  }

  void _setLoadingAndReload() {
    setState(() => _loadingAssets = true);
    _loadAssets();
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

/// One gallery cell: the asset thumbnail, with a duration badge for videos.
class _AssetThumb extends StatefulWidget {
  const _AssetThumb({super.key, required this.asset, required this.onTap});
  final AssetEntity asset;
  final VoidCallback onTap;

  @override
  State<_AssetThumb> createState() => _AssetThumbState();
}

class _AssetThumbState extends State<_AssetThumb> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize.square(300),
    );
    if (mounted) setState(() => _bytes = data);
  }

  String _dur(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.asset.type == AssetType.video;
    return PressScale(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: AppColors.layer2,
            child: _bytes == null
                ? const SizedBox.shrink()
                : Image.memory(_bytes!, fit: BoxFit.cover),
          ),
          if (isVideo)
            Positioned(
              right: 5,
              bottom: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      _dur(widget.asset.videoDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: AppType.small,
                        fontWeight: AppType.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
