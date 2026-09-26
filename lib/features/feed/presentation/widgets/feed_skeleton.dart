import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../widgets/motion/motion.dart';

/// First-load placeholder for the feed: a few post-card-shaped shimmer blocks,
/// so the screen reads as "loading real content" instead of a lone spinner.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key, this.count = 3});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: count,
        itemBuilder: (_, _) => const _SkeletonPost(),
      ),
    );
  }
}

class _SkeletonPost extends StatelessWidget {
  const _SkeletonPost();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar + name/location lines.
          Row(
            children: [
              const SkeletonBox(width: 40, height: 40, radius: AppRadius.pill),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: 120, height: 12),
                  SizedBox(height: 6),
                  SkeletonBox(width: 80, height: 10),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Media block (portrait-ish).
          AspectRatio(
            aspectRatio: 4 / 5,
            child: SkeletonBox(radius: AppRadius.lg, height: double.infinity),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Action row + caption lines.
          Row(
            children: const [
              SkeletonBox(width: 28, height: 14),
              SizedBox(width: AppSpacing.lg),
              SkeletonBox(width: 28, height: 14),
              SizedBox(width: AppSpacing.lg),
              SkeletonBox(width: 28, height: 14),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const SkeletonBox(width: 220, height: 12),
        ],
      ),
    );
  }
}
