import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import 'app_tile.dart' show AppAvatar;

/// How the ring around an [AvatarRing] reads.
enum AvatarRingStyle {
  /// Brand gradient — an active story / your own avatar.
  gradient,

  /// Muted solid ring — an inactive/seen state or a highlight cover.
  solid,

  /// No ring — a plain avatar (falls through to [AppAvatar]).
  none,
}

/// One avatar-with-ring, replacing the gradient/solid ring that was hand-built
/// in the story tray, highlights row and post header. Wraps the shared
/// [AppAvatar] so fallback/resize behaviour stays identical everywhere.
class AvatarRing extends StatelessWidget {
  const AvatarRing({
    super.key,
    required this.radius,
    this.imageProvider,
    this.style = AvatarRingStyle.gradient,
    this.ringWidth = 2,
    this.gap = false,
    this.fallbackIcon = Icons.person_rounded,
  });

  final double radius;
  final ImageProvider? imageProvider;
  final AvatarRingStyle style;
  final double ringWidth;

  /// Insets a scaffold-coloured gap between ring and avatar (story-tray look).
  final bool gap;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final avatar = AppAvatar(
      imageProvider: imageProvider,
      radius: radius,
      icon: fallbackIcon,
    );
    if (style == AvatarRingStyle.none) return avatar;

    final inner = gap
        ? Container(
            padding: const EdgeInsets.all(AppSpacing.xxs),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.scaffold,
            ),
            child: avatar,
          )
        : avatar;

    return Container(
      padding: EdgeInsets.all(ringWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: style == AvatarRingStyle.gradient
            ? LinearGradient(
                colors: [AppColors.primaryBright, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: style == AvatarRingStyle.solid ? AppColors.borderStrong : null,
      ),
      child: inner,
    );
  }
}
