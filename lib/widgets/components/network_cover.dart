import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';

/// A resilient cover image: fades in when loaded, and retries a few times on
/// failure (image CDNs throttle bursts of concurrent requests, e.g. a grid
/// loading many thumbnails at once). Falls back to [placeholder] only after the
/// retries are exhausted or the url is empty — so a transient blip no longer
/// leaves a permanent broken tile.
class NetworkCover extends StatefulWidget {
  const NetworkCover({
    super.key,
    required this.url,
    required this.placeholder,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.maxRetries = 3,
  });

  final String url;
  final Widget Function() placeholder;
  final BoxFit fit;
  final int? memCacheWidth;
  final int maxRetries;

  @override
  State<NetworkCover> createState() => _NetworkCoverState();
}

class _NetworkCoverState extends State<NetworkCover> {
  int _attempt = 0;
  bool _gaveUp = false;

  @override
  void didUpdateWidget(NetworkCover old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _attempt = 0;
      _gaveUp = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.isEmpty || _gaveUp) return widget.placeholder();

    return CachedNetworkImage(
      // A new key on each attempt forces a fresh fetch rather than replaying a
      // failed one.
      key: ValueKey('${widget.url}#$_attempt'),
      imageUrl: widget.url,
      fit: widget.fit,
      memCacheWidth: widget.memCacheWidth,
      fadeInDuration: AppMotion.base,
      placeholder: (_, _) => ColoredBox(color: AppColors.layer3),
      errorWidget: (_, _, _) {
        if (_attempt < widget.maxRetries) {
          // Back off a little longer each time, then retry.
          Future.delayed(Duration(milliseconds: 350 * (_attempt + 1)), () {
            if (mounted) setState(() => _attempt++);
          });
          // Keep the neutral loading tint while we retry (no error flash).
          return ColoredBox(color: AppColors.layer3);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_gaveUp) setState(() => _gaveUp = true);
        });
        return widget.placeholder();
      },
    );
  }
}
