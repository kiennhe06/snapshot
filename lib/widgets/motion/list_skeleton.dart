import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import 'shimmer.dart';

/// First-load placeholder for avatar+text lists (inbox, search, follow lists):
/// a few shimmering rows shaped like a list item, instead of a lone spinner.
class ListRowsSkeleton extends StatelessWidget {
  const ListRowsSkeleton({
    super.key,
    this.count = 7,
    this.avatarRadius = 24,
  });

  final int count;
  final double avatarRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: count,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              SkeletonBox(
                width: avatarRadius * 2,
                height: avatarRadius * 2,
                radius: AppRadius.pill,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 140, height: 12),
                    SizedBox(height: 8),
                    SkeletonBox(width: 220, height: 10),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const SkeletonBox(width: 34, height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
