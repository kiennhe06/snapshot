import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/spotify_track.dart';
import '../../../widgets/components/components.dart';
import '../../auth/providers/auth_providers.dart';
import '../../post/presentation/spotify_picker_sheet.dart';
import '../../profile/data/post_repository.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/reels_providers.dart';

/// Create a reel: pick/record a short video, add a caption and a music title.
/// (Trimming / transitions / AR filters need native SDKs and are out of scope.)
class ReelComposerScreen extends ConsumerStatefulWidget {
  const ReelComposerScreen({super.key, this.remixOfPostId, this.music});

  final String? remixOfPostId;
  final String? music;

  @override
  ConsumerState<ReelComposerScreen> createState() => _ReelComposerScreenState();
}

class _ReelComposerScreenState extends ConsumerState<ReelComposerScreen> {
  final _caption = TextEditingController();
  File? _video;
  SpotifyTrack? _track;
  bool _loading = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final x = await ImagePicker().pickVideo(source: source);
    if (x != null) setState(() => _video = File(x.path));
  }

  Future<void> _pickMusic() async {
    final track = await showSpotifyPicker(context);
    if (track != null && mounted) setState(() => _track = track);
  }

  Future<void> _post() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null || _video == null) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(postRepositoryProvider)
          .createPost(
            uid: uid,
            caption: _caption.text,
            media: [DraftMedia(file: _video!, isVideo: true)],
            musicTitle: _track?.name ?? widget.music,
            musicArtist: _track?.artist,
            musicCoverUrl: _track?.coverUrl,
            musicPreviewUrl: _track?.previewUrl,
            musicUrl: _track?.spotifyUrl,
            remixOfPostId: widget.remixOfPostId,
          );
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
        title: tr('Tạo thước phim', 'Create reel'),
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
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
          if (_video != null)
            Container(
              height: 160,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.layer3,
                borderRadius: AppRadius.brLg,
              ),
              child: Icon(
                Icons.videocam_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: tr('Chọn video', 'Pick video'),
                  variant: AppButtonVariant.secondary,
                  icon: Icons.video_library_outlined,
                  onPressed: () => _pick(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: tr('Quay', 'Record'),
                  variant: AppButtonVariant.secondary,
                  icon: Icons.videocam_outlined,
                  onPressed: () => _pick(ImageSource.camera),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _caption,
            label: tr('Chú thích', 'Caption'),
            hint: tr('Viết gì đó... #hashtag', 'Say something... #hashtag'),
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            tr('Âm thanh / Bài hát', 'Sound / Music'),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppType.label,
              fontWeight: AppType.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _MusicSelector(
            track: _track,
            onPick: _pickMusic,
            onRemove: () => setState(() => _track = null),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: tr('Chia sẻ thước phim', 'Share reel'),
            isLoading: _loading,
            icon: Icons.arrow_forward_rounded,
            onPressed: _post,
          ),
        ],
      ),
    );
  }
}

/// Row that either invites the user to pick a track or shows the selected one
/// (cover + title · artist) with a remove button. Uses the real iTunes picker.
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
