import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
              child: const Icon(Icons.add, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              tr('Mới', 'New'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppType.small,
              ),
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
            Container(
              width: 62,
              height: 62,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderStrong, width: 2),
              ),
              child: CircleAvatar(
                backgroundColor: AppColors.layer3,
                backgroundImage: h.coverUrl.isNotEmpty
                    ? CachedNetworkImageProvider(h.coverUrl)
                    : null,
                child: h.coverUrl.isEmpty
                    ? const Icon(
                        Icons.star_rounded,
                        color: AppColors.textSecondary,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: 66,
              child: Text(
                h.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppType.small,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final stories = ref.read(myStoriesProvider).valueOrNull ?? const [];
    if (stories.isEmpty) {
      showAppToast(
        context,
        tr(
          'Bạn chưa có tin đang hoạt động để ghim.',
          'You have no active stories to highlight.',
        ),
      );
      return;
    }
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
                tr('Tạo highlight', 'New highlight'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppType.title,
                  fontWeight: AppType.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(controller: controller, label: tr('Tên', 'Title')),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: tr('Tạo', 'Create'),
                onPressed: () => Navigator.pop(dctx, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true && controller.text.trim().isNotEmpty) {
      await ref
          .read(highlightRepositoryProvider)
          .createHighlight(
            uid: uid,
            title: controller.text.trim(),
            coverUrl: stories.first.mediaUrl,
            storyIds: stories.map((s) => s.storyId).toList(),
          );
    }
  }

  Future<void> _open(BuildContext context, WidgetRef ref, Highlight h) async {
    final repo = ref.read(storyRepositoryProvider);
    final stories = <Story>[];
    for (final id in h.storyIds) {
      final s = await repo.getStory(id);
      if (s != null) stories.add(s);
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
