import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import 'press_scale.dart';

/// The single source of truth for every raised block. Never build a card with a
/// bare `Container(decoration:)` in a screen — use this so depth stays uniform.
///
/// Depth = 4 layers: surface gradient + double shadow + top highlight border
/// (+ optional brand glow for live/featured elements).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.onTap,
    this.onLongPress,
    this.elevated = false,
    this.glow = false,
    this.borderColor,
    this.radius,
    this.clip = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool elevated;
  final bool glow;
  final Color? borderColor;
  final double? radius;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final shadows = <BoxShadow>[
      ...(elevated ? AppShadows.medium : AppShadows.soft),
      if (glow) ...AppShadows.brandGlow,
    ];
    final card = Container(
      margin: margin,
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        gradient: elevated ? AppGradients.elevated : AppGradients.card,
        borderRadius: BorderRadius.circular(radius ?? AppRadius.xl),
        border: Border.all(
          color: borderColor ?? AppColors.borderSubtle,
          width: 1,
        ),
        boxShadow: shadows,
      ),
      child: child,
    );
    if (onTap == null && onLongPress == null) return card;
    return PressScale(onTap: onTap, onLongPress: onLongPress, child: card);
  }
}
