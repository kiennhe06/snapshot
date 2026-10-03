import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/story.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/components/components.dart';
import '../../../widgets/empty_view.dart';
import '../providers/story_providers.dart';

/// The owner's personal story archive: every story they've posted, saved
/// automatically and kept after the 24-hour expiry so it can be reviewed.
class StoryArchiveScreen extends ConsumerWidget {
  const StoryArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      topBar: AppTopBar(
        title: tr('Kho lưu trữ tin', 'Stories archive'),
        showBack: true,
      ),
      body: AsyncValueView<List<Story>>(
        value: ref.watch(storyArchiveProvider),
        onRetry: () => ref.invalidate(storyArchiveProvider),
        builder: (stories) {
          if (stories.isEmpty) {
            return EmptyView(
              message: tr(
                'Chưa có tin nào được lưu trữ.\nTin bạn đăng sẽ tự lưu ở đây.',
                'No archived stories yet.\nStories you post are saved here.',
              ),
              icon: Icons.auto_stories_rounded,
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
              childAspectRatio: 0.6,
            ),
            itemCount: stories.length,
            itemBuilder: (_, i) => _ArchiveTile(story: stories[i]),
          );
        },
      ),
    );
  }
}

class _ArchiveTile extends StatelessWidget {
  const _ArchiveTile({required this.story});
  final Story story;

  bool get _isVideo => story.mediaType == 'video';
  bool get _isActive => story.expiresAt.isAfter(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _StoryArchiveViewer(story: story),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: AppColors.layer2),
            if (_isVideo)
              Center(
                child: Icon(
                  Icons.videocam_rounded,
                  color: AppColors.textSecondary,
                  size: AppIconSize.lg,
                ),
              )
            else
              CachedNetworkImage(imageUrl: story.mediaUrl, fit: BoxFit.cover),
            // Bottom scrim + date.
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 44,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0x99000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 6,
              bottom: 6,
              child: Text(
                DateFormat('dd/MM/yy').format(story.createdAt),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppType.small,
                  fontWeight: AppType.bold,
                ),
              ),
            ),
            if (_isActive)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    tr('Đang hiện', 'Live'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: AppType.small,
                      fontWeight: AppType.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen view of one archived story, with a delete action.
class _StoryArchiveViewer extends ConsumerWidget {
  const _StoryArchiveViewer({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVideo = story.mediaType == 'video';
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: isVideo
                  ? AppVideo(url: story.mediaUrl, active: true)
                  : InteractiveViewer(
                      child: Center(
                        child: CachedNetworkImage(imageUrl: story.mediaUrl),
                      ),
                    ),
            ),
            // Top bar: close + date + delete.
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
                    Expanded(
                      child: Text(
                        DateFormat('dd/MM/yyyy · HH:mm').format(story.createdAt),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: AppType.medium,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => _confirmDelete(context, ref),
                    ),
                  ],
                ),
              ),
            ),
            if (story.caption != null && story.caption!.isNotEmpty)
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.xl,
                child: Text(
                  story.caption!,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showAppConfirm(
      context,
      title: tr('Xoá tin này?', 'Delete this story?'),
      message: tr(
        'Tin sẽ bị xoá vĩnh viễn khỏi kho lưu trữ.',
        'This story will be permanently removed from your archive.',
      ),
      confirmLabel: tr('Xoá', 'Delete'),
      cancelLabel: tr('Huỷ', 'Cancel'),
      destructive: true,
    );
    if (!ok) return;
    await ref.read(storyRepositoryProvider).deleteStory(story.storyId);
    if (context.mounted) Navigator.of(context).maybePop();
  }
}
