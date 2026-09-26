import 'package:flutter/material.dart';

import '../../core/design/motion.dart';
import '../../core/design/tokens.dart';

/// Sweeps a soft highlight across its subtree — the app's "content is loading"
/// texture. Wrap a tree of [SkeletonBox]es in one [Shimmer] so they pulse
/// together. Under reduced motion it renders the static base tint (no sweep).
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    final base = AppColors.layer3;
    final highlight = AppColors.layer5;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _c.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = bounds.width;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: const [0.30, 0.50, 0.70],
              transform: _SlideGradient(t * 2 - 1, dx),
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

/// Translates the shimmer gradient horizontally across the masked bounds.
class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.slidePercent, this.width);
  final double slidePercent;
  final double width;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(slidePercent * width, 0, 0);
}

/// A single rounded placeholder block. Paint several inside one [Shimmer].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = AppRadius.sm,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.layer3,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
