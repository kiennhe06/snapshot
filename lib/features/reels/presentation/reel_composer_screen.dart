import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../widgets/components/components.dart';
import '../../auth/providers/auth_providers.dart';
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
  late final TextEditingController _music = TextEditingController(
    text: widget.music ?? '',
  );
  File? _video;
  bool _loading = false;

  @override
  void dispose() {
    _caption.dispose();
    _music.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final x = await ImagePicker().pickVideo(source: source);
    if (x != null) setState(() => _video = File(x.path));
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
            musicTitle: _music.text,
            remixOfPostId: widget.remixOfPostId,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Đã đăng reel.', 'Reel posted.'))),
        );
        ref.read(reelsControllerProvider.notifier).refresh();
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Đăng reel thất bại.', 'Failed to post reel.')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: AppTopBar(title: tr('Tạo reel', 'Create reel'), showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (widget.remixOfPostId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                tr('Bạn đang remix một reel.', 'You are remixing a reel.'),
                style: const TextStyle(
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
              child: const Icon(
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
          AppTextField(
            controller: _music,
            label: tr('Nhạc (tên bài hát)', 'Music (song title)'),
            icon: Icons.music_note_rounded,
            hint: tr('ví dụ: Chúng ta của hiện tại', 'e.g. Blinding Lights'),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: tr('Đăng reel', 'Share reel'),
            isLoading: _loading,
            onPressed: _post,
          ),
        ],
      ),
    );
  }
}
