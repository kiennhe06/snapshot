import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/spotify_track.dart';
import '../../../widgets/components/components.dart';
import '../../auth/providers/auth_providers.dart';
import '../../post/presentation/spotify_picker_sheet.dart';
import '../../profile/data/post_repository.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/reels_providers.dart';

/// Create a reel: pick/record a short video, add a caption, tag a location and
/// attach a real (playable) track. The caption + music draft auto-saves locally.
/// (Trimming / cover-frame extraction need native SDKs and are out of scope.)
class ReelComposerScreen extends ConsumerStatefulWidget {
  const ReelComposerScreen({super.key, this.remixOfPostId, this.music});

  final String? remixOfPostId;
  final String? music;

  @override
  ConsumerState<ReelComposerScreen> createState() => _ReelComposerScreenState();
}

class _ReelComposerScreenState extends ConsumerState<ReelComposerScreen> {
  static const _draftKey = 'reel_draft_caption_v1';

  final _caption = TextEditingController();
  File? _video;
  SpotifyTrack? _track;
  String? _location;
  bool _loading = false;
  bool _savedHint = false;

  @override
  void initState() {
    super.initState();
    _loadDraft();
    _caption.addListener(_saveDraft);
  }

  @override
  void dispose() {
    _caption.removeListener(_saveDraft);
    _caption.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_draftKey);
      if (saved != null && saved.isNotEmpty && mounted) {
        _caption.text = saved;
      }
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    setState(() => _savedHint = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_draftKey, _caption.text);
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  Future<void> _pick(ImageSource source) async {
    final x = await ImagePicker().pickVideo(source: source);
    if (x != null) setState(() => _video = File(x.path));
  }

  Future<void> _pickMusic() async {
    final track = await showSpotifyPicker(context);
    if (track != null && mounted) setState(() => _track = track);
  }

  void _insert(String s) {
    final t = _caption;
    final sel = t.selection;
    final base = t.text;
    if (sel.isValid) {
      t.text = base.replaceRange(sel.start, sel.end, s);
      t.selection = TextSelection.collapsed(offset: sel.start + s.length);
    } else {
      t.text = base + s;
      t.selection = TextSelection.collapsed(offset: t.text.length);
    }
  }

  Future<void> _pickLocation() async {
    final controller = TextEditingController(text: _location ?? '');
    final v = await showAppSheet<String?>(
      context,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: AppSheetSurface(
          title: tr('Vị trí', 'Location'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: controller,
                label: tr('Địa điểm', 'Place'),
                hint: tr('TP. Hồ Chí Minh', 'City, place…'),
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: tr('Xong', 'Done'),
                onPressed: () => Navigator.pop(sheetCtx, controller.text.trim()),
              ),
            ],
          ),
        ),
      ),
    );
    if (v != null) setState(() => _location = v.isEmpty ? null : v);
  }

  Future<void> _emojiSheet() async {
    const emojis = ['✨', '🔥', '❤️', '😍', '📷', '🎬', '☕', '🌇', '👏', '🙌'];
    await showAppSheet<void>(
      context,
      builder: (sheetCtx) => AppSheetSurface(
        title: tr('Biểu tượng', 'Emoji'),
        child: Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final e in emojis)
              PressScale(
                onTap: () {
                  _insert(e);
                  Navigator.pop(sheetCtx);
                },
                child: Text(e, style: const TextStyle(fontSize: 30)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _post() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null || _video == null) {
      if (_video == null) {
        showAppToast(
          context,
          tr('Hãy chọn một video trước.', 'Pick a video first.'),
          type: AppToastType.error,
        );
      }
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(postRepositoryProvider)
          .createPost(
            uid: uid,
            caption: _caption.text,
            media: [DraftMedia(file: _video!, isVideo: true)],
            location: _location,
            musicTitle: _track?.name ?? widget.music,
            musicArtist: _track?.artist,
            musicCoverUrl: _track?.coverUrl,
            musicPreviewUrl: _track?.previewUrl,
            musicUrl: _track?.spotifyUrl,
            remixOfPostId: widget.remixOfPostId,
          );
      await _clearDraft();
      if (mounted) {
        showAppToast(
          context,
          tr('Đã đăng reel.', 'Reel posted.'),
          type: AppToastType.success,
        );
        ref.read(reelsControllerProvider.notifier).refresh();
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        showAppToast(
          context,
          tr('Đăng reel thất bại.', 'Failed to post reel.'),
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: AppTopBar(
        showBack: true,
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('Tạo thước phim', 'Create reel'),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppType.headline,
                    fontWeight: AppType.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            Text(
              _savedHint
                  ? tr('Bản nháp đã lưu', 'Draft saved')
                  : tr('Bản nháp tự động lưu', 'Draft auto-saves'),
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: AppType.small,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        children: [
          if (widget.remixOfPostId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                tr('Bạn đang remix một reel.', 'You are remixing a reel.'),
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: AppType.bold,
                ),
              ),
            ),
          // Source buttons: pick (outlined) + record (gradient).
          Row(
            children: [
              Expanded(
                child: _SourceButton(
                  icon: Icons.movie_outlined,
                  label: tr('Chọn video', 'Pick video'),
                  filled: false,
                  onTap: () => _pick(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _SourceButton(
                  icon: Icons.videocam_rounded,
                  label: tr('Quay video', 'Record'),
                  filled: true,
                  onTap: () => _pick(ImageSource.camera),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _PreviewCard(hasVideo: _video != null, onTap: () => _pick(ImageSource.gallery)),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel(tr('Chú thích & Hashtag', 'Caption & Hashtag')),
          const SizedBox(height: AppSpacing.sm),
          _CaptionCard(
            controller: _caption,
            location: _location,
            onHashtag: () => _insert('#'),
            onMention: () => _insert('@'),
            onLocation: _pickLocation,
            onEmoji: _emojiSheet,
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionLabel(tr('Âm thanh / Bài hát', 'Sound / Music')),
              Text(
                tr('Thịnh hành', 'Trending'),
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: AppType.label,
                  fontWeight: AppType.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _MusicSelector(
            track: _track,
            onPick: _pickMusic,
            onRemove: () => setState(() => _track = null),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _GradientButton(
            label: tr('Chia sẻ thước phim', 'Share reel'),
            loading: _loading,
            onTap: _post,
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
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: AppColors.textPrimary,
      fontSize: AppType.subhead,
      fontWeight: AppType.bold,
    ),
  );
}

/// Large pill source button; [filled] paints the brand gradient (Record).
class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: filled
              ? LinearGradient(
                  colors: [AppColors.primaryBright, AppColors.primary],
                )
              : null,
          color: filled ? null : AppColors.layer1,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: filled ? Colors.transparent : AppColors.primary,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: filled ? Colors.white : AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                color: filled ? Colors.white : AppColors.textPrimary,
                fontSize: AppType.subhead,
                fontWeight: AppType.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark preview frame: tap to pick a video. Shows a picked state honestly
/// (no fake trim/cover controls — those need native video processing).
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.hasVideo, required this.onTap});
  final bool hasVideo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.layer1,
          borderRadius: AppRadius.brLg,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  tr('XEM TRƯỚC KHUNG HÌNH', 'FRAME PREVIEW'),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppType.label,
                    fontWeight: AppType.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.layer3,
                  borderRadius: AppRadius.brMd,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Icon(
                        hasVideo
                            ? Icons.check_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      hasVideo
                          ? tr('Đã chọn video · nhấn để đổi', 'Video selected · tap to change')
                          : tr('Nhấn để chọn video', 'Tap to pick a video'),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppType.label,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.crop_portrait_rounded,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  tr('Dọc 9:16', 'Vertical 9:16'),
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: AppType.small,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Caption text box + a chip row (# @ location emoji).
class _CaptionCard extends StatelessWidget {
  const _CaptionCard({
    required this.controller,
    required this.location,
    required this.onHashtag,
    required this.onMention,
    required this.onLocation,
    required this.onEmoji,
  });

  final TextEditingController controller;
  final String? location;
  final VoidCallback onHashtag;
  final VoidCallback onMention;
  final VoidCallback onLocation;
  final VoidCallback onEmoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.layer1,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            maxLines: 4,
            minLines: 3,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: tr(
                'Viết điều gì đó… #xuhuong #travel #reelsvn',
                'Say something… #trending #travel #reels',
              ),
              hintStyle: TextStyle(color: AppColors.textTertiary),
            ),
          ),
          const Divider(height: AppSpacing.lg),
          Row(
            children: [
              _Chip(icon: Icons.tag_rounded, label: tr('Thẻ tag', 'Hashtag'), onTap: onHashtag),
              const SizedBox(width: AppSpacing.sm),
              _Chip(icon: Icons.alternate_email_rounded, label: tr('Gắn thẻ', 'Tag'), onTap: onMention),
              const SizedBox(width: AppSpacing.sm),
              _Chip(
                icon: Icons.location_on_outlined,
                label: location ?? tr('Vị trí', 'Location'),
                highlight: location != null,
                onTap: onLocation,
              ),
              const Spacer(),
              PressScale(
                onTap: onEmoji,
                child: Icon(
                  Icons.emoji_emotions_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: highlight
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.layer2,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: highlight ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 90),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: highlight
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontSize: AppType.label,
                  fontWeight: AppType.medium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row that invites picking a track or shows the selected one (real iTunes).
class _MusicSelector extends StatelessWidget {
  const _MusicSelector({
    required this.track,
    required this.onPick,
    required this.onRemove,
  });

  final SpotifyTrack? track;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = track;
    return PressScale(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.layer1,
          borderRadius: AppRadius.brLg,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: (t?.coverUrl ?? '').isNotEmpty
                  ? CachedNetworkImage(imageUrl: t!.coverUrl, fit: BoxFit.cover)
                  : Icon(Icons.music_note_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: t == null
                  ? Text(
                      tr('Thêm âm thanh', 'Add sound'),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: AppType.bold,
                        fontSize: AppType.subhead,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: AppType.bold,
                            fontSize: AppType.subhead,
                          ),
                        ),
                        Text(
                          t.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: AppType.label,
                          ),
                        ),
                      ],
                    ),
            ),
            if (t == null)
              Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary)
            else
              GestureDetector(
                onTap: onRemove,
                child: Icon(
                  Icons.close_rounded,
                  color: AppColors.textTertiary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-width brand-gradient share button.
class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });
  final String label;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: loading ? null : onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryBright, AppColors.primary, AppColors.accent],
          ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: AppShadows.soft,
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: AppType.headline,
                      fontWeight: AppType.heavy,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ],
              ),
      ),
    );
  }
}
