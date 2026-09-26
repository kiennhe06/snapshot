import 'package:flutter/material.dart';

import '../../core/design/motion.dart';
import '../../core/design/tokens.dart';

/// Custom tap wrapper that scales down slightly while pressed (replaces the
/// default Material ink/hover feedback with a consistent, on-brand press).
///
/// This is the app's press verb: a single, consistent scale-down for every
/// tappable surface. Set [enableHaptic] to pair it with a light tap; the scale
/// collapses to instant under reduced motion.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.enableHaptic = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool enableHaptic;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    setState(() => _down = v);
  }

  void _handleTap() {
    if (widget.enableHaptic) Motion.tap();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Under reduced motion the press still registers, just without the scale.
    final target = _down && !Motion.reduced(context) ? widget.scale : 1.0;
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null ? null : _handleTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: target,
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        child: widget.child,
      ),
    );
  }
}
