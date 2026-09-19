import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/post.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/components/components.dart';
import '../../../widgets/empty_view.dart';
import '../providers/reels_providers.dart';

/// All reels that use a given music track.
class MusicPageScreen extends ConsumerWidget {
  const MusicPageScreen({super.key, required this.musicTitle});

  final String musicTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reelsAsync = ref.watch(musicReelsProvider(musicTitle));

    return AppScaffold(
      topBar: AppTopBar(
        showBack: true,
        titleWidget: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppGradients.elevated,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                Icons.music_note_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    musicTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppType.subhead,
                      fontWeight: AppType.bold,
                    ),
                  ),
                  Text(
                    tr('Âm thanh', 'Audio'),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppType.small,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: AsyncValueView<List<Post>>(
        value: reelsAsync,
        onRetry: () => ref.invalidate(musicReelsProvider(musicTitle)),
        builder: (reels) {
          if (reels.isEmpty) {
            return EmptyView(
              message: tr(
                'Chưa có reel nào dùng âm thanh này.',
                'No reels use this audio yet.',
              ),
              icon: Icons.music_off_rounded,
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Text(
                      '${reels.length} ${tr('reel', 'reels')}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: AppType.medium,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 0.6,
                  ),
                  itemCount: reels.length,
                  itemBuilder: (_, i) => _cover(context, reels[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _cover(BuildContext context, Post p) {
    return PressScale(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => _SingleReel(post: p))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: p.coverUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: AppColors.layer3),
              errorWidget: (_, _, _) => Container(color: AppColors.layer3),
            ),
            const Center(
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white70,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleReel extends StatelessWidget {
  const _SingleReel({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: post.media.isEmpty
                ? const ColoredBox(color: Colors.black)
                : AppVideo(url: post.media.first.url),
          ),
          SafeArea(
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}
