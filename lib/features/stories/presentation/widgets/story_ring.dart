import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../providers/story_providers.dart';
import '../story_composer_screen.dart';
import '../story_viewer_screen.dart';

/// Horizontal story tray row shown at the top of the feed.
class StoryRing extends ConsumerWidget {
  const StoryRing({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final trays = ref.watch(storyTraysProvider).valueOrNull ?? const [];
    final hasOwn = trays.isNotEmpty && trays.first.authorId == myUid;

    return SizedBox(
      height: 104,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          // Your story bubble (add or open own).
          _YourStory(
            hasStory: hasOwn,
            onAdd: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StoryComposerScreen()),
            ),
            onOpen: () => _openViewer(context, trays, 0),
          ),
          for (var i = 0; i < trays.length; i++)
            if (trays[i].authorId != myUid)
              _TrayBubble(
                authorId: trays[i].authorId,
                onTap: () => _openViewer(context, trays, i),
              ),
        ],
      ),
    );
  }

  void _openViewer(BuildContext context, List trays, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            StoryViewerScreen(trays: trays.cast(), initialIndex: index),
      ),
    );
  }
}

class _YourStory extends ConsumerWidget {
  const _YourStory({
    required this.hasStory,
    required this.onAdd,
    required this.onOpen,
  });

  final bool hasStory;
  final VoidCallback onAdd;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myProfileProvider).valueOrNull;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: GestureDetector(
        onTap: hasStory ? onOpen : onAdd,
        child: Column(
          children: [
            Stack(
              children: [
                _ringAvatar(me?.photoUrl, active: hasStory),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.scaffold, width: 2),
                    ),
                    child: const Icon(Icons.add, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              tr('Tin của bạn', 'Your story'),
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
}

class _TrayBubble extends ConsumerWidget {
  const _TrayBubble({required this.authorId, required this.onTap});
  final String authorId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider(authorId)).valueOrNull;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            _ringAvatar(user?.photoUrl, active: true),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: 68,
              child: Text(
                user?.username.isNotEmpty == true
                    ? user!.username
                    : (user?.displayName ?? '...'),
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
}

Widget _ringAvatar(String? photoUrl, {required bool active}) {
  return Container(
    padding: const EdgeInsets.all(2.5),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: active
          ? const LinearGradient(
              colors: [AppColors.primaryBright, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      color: active ? null : AppColors.borderStrong,
    ),
    child: Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.scaffold,
      ),
      child: CircleAvatar(
        radius: 30,
        backgroundColor: AppColors.layer3,
        backgroundImage: photoUrl != null
            ? CachedNetworkImageProvider(photoUrl)
            : null,
        child: photoUrl == null
            ? const Icon(Icons.person_rounded, color: AppColors.textSecondary)
            : null,
      ),
    ),
  );
}
