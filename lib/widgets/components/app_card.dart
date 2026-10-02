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
    final lego = isLegoDisplay;
    final shadows = lego
        ? AppDepth.brickShadow(dy: 5)
        : <BoxShadow>[
            ...(elevated ? AppShadows.medium : AppShadows.soft),
            if (glow) ...AppShadows.brandGlow,
          ];
    // LEGO: a studs strip sits on top of the brick, above the content.
    final content = lego
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: LegoStuds(),
              ),
              child,
            ],
          )
        : child;
    final card = Container(
      margin: margin,
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        gradient: elevated ? AppGradients.elevated : AppGradients.card,
        borderRadius: BorderRadius.circular(radius ?? AppRadius.xl),
        border: lego
            ? AppDepth.brickBorder(width: 2.5)
            : Border.all(
                color: borderColor ?? AppColors.borderSubtle,
                width: 1,
              ),
        boxShadow: shadows,
      ),
      child: content,
    );
    if (onTap == null && onLongPress == null) return card;
    return PressScale(onTap: onTap, onLongPress: onLongPress, child: card);
  }
}

/// A row of LEGO studs (the round bumps on top of a brick). Renders only as a
/// small strip; used at the top of [AppCard] on the LEGO skin.
class LegoStuds extends StatelessWidget {
  const LegoStuds({super.key, this.count = 5, this.studWidth = 16});
  final int count;
  final double studWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        return Container(
          width: studWidth,
          height: studWidth * 0.62,
          margin: EdgeInsets.only(right: i == count - 1 ? 0 : studWidth * 0.55),
          decoration: BoxDecoration(
            color: AppColors.layer3,
            borderRadius: BorderRadius.circular(studWidth),
            border: Border.all(color: const Color(0xFF17120F), width: 2),
          ),
        );
      }),
    );
  }
}
