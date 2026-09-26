import 'package:flutter/widgets.dart';

import '../../core/design/motion.dart';
import '../../core/design/tokens.dart';

/// A number that rolls to its new value instead of snapping — the app's verb
/// for "a count changed". Used for likes, followers, comments, so a tap has a
/// visible consequence. Formats through [format] (e.g. `formatCount`).
class MotionCountUp extends StatelessWidget {
  const MotionCountUp({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = AppMotion.base,
  });

  final int value;
  final String Function(int) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Keyed by value so each change animates from the previous number.
      tween: Tween(begin: value.toDouble(), end: value.toDouble()),
      duration: Motion.dur(context, duration),
      curve: AppMotion.standard,
      builder: (context, v, _) => Text(format(v.round()), style: style),
    );
  }
}
