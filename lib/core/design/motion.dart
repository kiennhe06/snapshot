import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Runtime side of the motion language: reduced-motion awareness and the haptic
/// vocabulary that fires alongside motion so touch and sight agree.
///
/// Tokens (durations, curves, springs, stagger) live in [AppMotion]; this class
/// is the behaviour that adapts them to the device and the user.
abstract class Motion {
  /// Whether the OS asked apps to minimize motion (iOS "Reduce Motion",
  /// Android "Remove animations"). Motion collapses to instant when true.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// A duration that becomes [Duration.zero] under reduced motion.
  static Duration dur(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;

  /// Stagger delay for the [index]-th item in a group, capped so long lists
  /// never feel slow, and disabled entirely under reduced motion.
  static Duration stagger(
    BuildContext context,
    int index, {
    Duration step = const Duration(milliseconds: 45),
    int cap = 8,
  }) {
    if (reduced(context)) return Duration.zero;
    return step * (index.clamp(0, cap));
  }

  // ---- Haptic vocabulary --------------------------------------------------
  // Each maps a motion event class to a consistent touch response.

  /// A light tap — pressing a control (pairs with the press-scale).
  static void tap() => HapticFeedback.lightImpact();

  /// A firmer tap — a state toggled on (like, save, follow).
  static void toggle() => HapticFeedback.mediumImpact();

  /// A crisp click — moving between discrete options (tabs, segments, stories).
  static void selection() => HapticFeedback.selectionClick();

  /// Completion — a send/publish/confirm succeeded.
  static void success() => HapticFeedback.mediumImpact();
}
