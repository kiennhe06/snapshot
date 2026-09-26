import 'package:flutter/widgets.dart';

import '../../core/design/motion.dart';
import '../../core/design/tokens.dart';

/// Choreographed entrance: the child fades, rises and settles into place once,
/// on first appearance, after an optional stagger delay based on [index].
///
/// This is the app's group-entrance verb — feed cards, grid cells, story rings
/// and list rows all speak it, so lists assemble instead of blinking in. Honors
/// reduced motion (shows instantly) and never re-runs on rebuild.
class MotionEntrance extends StatefulWidget {
  const MotionEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.animate = true,
    this.offset = 14,
    this.duration = AppMotion.expressive,
    this.staggerStep = AppMotion.stagger,
    this.staggerCap = AppMotion.staggerMax,
  });

  final Widget child;

  /// Position within its group; drives the stagger delay.
  final int index;

  /// When false the child appears resolved (no entrance). Callers set this to
  /// false for items that have already entered — e.g. list rows recycled on
  /// scroll — so the entrance plays once per item, not on every rebuild.
  final bool animate;

  /// How far (logical px) the child rises from.
  final double offset;

  final Duration duration;
  final Duration staggerStep;
  final int staggerCap;

  @override
  State<MotionEntrance> createState() => _MotionEntranceState();
}

class _MotionEntranceState extends State<MotionEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: AppMotion.enter,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate || Motion.reduced(context)) {
      _c.value = 1; // already entered, or motion disabled — show resolved
      return;
    }
    final delay = Motion.stagger(
      context,
      widget.index,
      step: widget.staggerStep,
      cap: widget.staggerCap,
    );
    Future.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) {
        final v = _t.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * widget.offset),
            child: Transform.scale(
              scale: 0.985 + 0.015 * v,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
