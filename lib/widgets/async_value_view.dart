import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'error_view.dart';
import 'loading_view.dart';

/// Stale-while-revalidate view for an [AsyncValue].
///
/// - has data: render [builder], overlay a thin progress bar while refreshing.
/// - loading (no data yet): [LoadingView].
/// - error (no data): [ErrorView] with retry.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.builder,
    required this.onRetry,
    this.errorMessage,
    this.isEmpty,
    this.empty,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  final String? errorMessage;

  /// Optional: treat this data as "empty" and render [empty] instead of
  /// [builder]. Keeps empty-state handling consistent across screens.
  final bool Function(T data)? isEmpty;
  final Widget Function(T data)? empty;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) {
      final data = value.requireValue;
      if (isEmpty != null && empty != null && isEmpty!(data)) {
        return empty!(data);
      }
      return Stack(
        children: [
          builder(data),
          if (value.isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      );
    }
    if (value.isLoading) return const LoadingView();
    return ErrorView(
      message: errorMessage ?? 'Đã xảy ra lỗi, vui lòng thử lại.',
      onRetry: onRetry,
    );
  }
}
