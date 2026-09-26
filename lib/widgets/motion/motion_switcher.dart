import 'package:flutter/widgets.dart';

import '../../core/design/motion.dart';
import '../../core/design/tokens.dart';

/// The app's verb for "this region became something else" — a gentle
/// cross-fade with a hair of scale, so loading→data→empty→error resolve
/// instead of snapping. Give each state child a distinct [ValueKey] so the
/// switcher knows the content changed. Honors reduced motion.
class MotionSwitcher extends StatelessWidget {
  const MotionSwitcher({
    super.key,
    required this.child,
    this.duration = AppMotion.base,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final Duration duration;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.dur(context, duration),
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.985, end: 1).animate(anim),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
