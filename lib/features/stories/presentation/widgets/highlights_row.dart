import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../models/story.dart';
import '../../../../widgets/components/components.dart';
import '../../providers/story_providers.dart';
import '../story_viewer_screen.dart';

/// Row of profile highlights. Owners can create a highlight from their active
/// stories via the leading "+" bubble.
class HighlightsRow extends ConsumerWidget {
  const HighlightsRow({super.key, required this.uid, required this.isMe});

  final String uid;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlights =
        ref.watch(highlightsProvider(uid)).valueOrNull ?? const [];
    if (highlights.isEmpty && !isMe) return const SizedBox.shrink();

    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          if (isMe) _newBubble(context, ref),
          for (final h in highlights) _bubble(context, ref, h),
        ],
      ),
    );
  }

  Widget _newBubble(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: GestureDetector(
        onTap: () => _create(context, ref),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.layer3,
                border: Border.all(color: AppColors.borderStrong),
              ),
              child: Icon(Icons.add, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              tr('Mới', 'New'),
              style: AppText.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(BuildContext context, WidgetRef ref, Highlight h) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: GestureDetector(
        onTap: () => _open(context, ref, h),
        child: Column(
          children: [
            AvatarRing(
              radius: 27,
              imageProvider: h.coverUrl.isNotEmpty
                  ? CachedNetworkImageProvider(h.coverUrl)
                  : null,
              style: AvatarRingStyle.solid,
              fallbackIcon: Icons.star_rounded,
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: 66,
              child: Text(
                h.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final stories = ref.read(myStoriesProvider).valueOrNull ?? const [];
    final repo = ref.read(highlightRepositoryProvider);

    if (stories.isNotEmpty) {
      // Highlight the active stories.
      final title = await _promptTitle(context);
      if (title == null || title.isEmpty) return;
      await repo.createHighlight(
        uid: uid,
        title: title,
        coverUrl: stories.first.mediaUrl,
        storyIds: stories.map((s) => s.storyId).toList(),
      );
      return;
    }

    // No active story: let the user pick a photo to build a highlight directly.
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1080,
    );
    if (x == null || !context.mounted) return;
    final title = await _promptTitle(context);
    if (title == null || title.isEmpty) return;
    await repo.createHighlightFromMedia(
      uid: uid,
      title: title,
      file: File(x.path),
    );
  }

  Future<String?> _promptTitle(BuildContext context) {
    final controller = TextEditingController();
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
              Text(
                tr('Tạo highlight', 'New highlight'),
                style: AppText.h1,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(controller: controller, label: tr('Tên', 'Title')),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: tr('Tạo', 'Create'),
                onPressed: () => Navigator.pop(dctx, controller.text.trim()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, Highlight h) async {
    final repo = ref.read(storyRepositoryProvider);
    final stories = <Story>[];
    for (final id in h.storyIds) {
      final s = await repo.getStory(id);
      if (s != null) stories.add(s);
    }
    // A media-only highlight (no source stories) renders its cover as a frame.
    if (stories.isEmpty && h.coverUrl.isNotEmpty) {
      final now = DateTime.now();
      stories.add(
        Story(
          storyId: h.id,
          authorId: uid,
          mediaUrl: h.coverUrl,
          mediaType: 'image',
          caption: h.title,
          createdAt: now,
          expiresAt: now,
        ),
      );
    }
    if (stories.isEmpty || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryViewerScreen(
          trays: [StoryTray(authorId: uid, stories: stories)],
          initialIndex: 0,
        ),
      ),
    );
  }
}
