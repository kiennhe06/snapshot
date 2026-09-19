import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';

/// The single bottom-sheet foundation for the whole app. Every modal sheet
/// (menus, pickers, editors, confirmations) should present through
/// [showAppSheet] and lay its content inside an [AppSheetSurface], so the
/// handle, surface, radius, shadow and safe-area are identical everywhere.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: isScrollControlled,
    isDismissible: dismissible,
    enableDrag: dismissible,
    builder: builder,
  );
}

/// The consistent sheet container: floating rounded card + grab handle + an
/// optional title, sized to its content up to [maxHeightFactor] of the screen.
class AppSheetSurface extends StatelessWidget {
  const AppSheetSurface({
    super.key,
    required this.child,
    this.title,
    this.maxHeightFactor = 0.82,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.md,
    ),
  });

  final Widget child;
  final String? title;
  final double maxHeightFactor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.md,
        top: AppSpacing.md,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * maxHeightFactor,
      ),
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.layer1,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.medium,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: AppSpacing.sm,
                  top: AppSpacing.xs,
                ),
                child: Text(
                  title!,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppType.headline,
                    fontWeight: AppType.bold,
                  ),
                ),
              ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
