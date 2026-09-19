import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/design/tokens.dart';

/// A network video player: autoplay + loop when [active], tap to pause/resume,
/// optional [muted]. Used for reels, and post/story video.
class AppVideo extends StatefulWidget {
  const AppVideo({
    super.key,
    required this.url,
    this.active = true,
    this.muted = false,
    this.fit = BoxFit.cover,
    this.loop = true,
    this.showControls = true,
  });

  final String url;
  final bool active;
  final bool muted;
  final BoxFit fit;
  final bool loop;
  final bool showControls;

  @override
  State<AppVideo> createState() => _AppVideoState();
}

class _AppVideoState extends State<AppVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _showPause = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = c;
    try {
      await c.initialize();
      await c.setLooping(widget.loop);
      await c.setVolume(widget.muted ? 0 : 1);
      if (widget.active) await c.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _ready = false);
    }
  }

  @override
  void didUpdateWidget(covariant AppVideo old) {
    super.didUpdateWidget(old);
    final c = _controller;
    if (c == null || !_ready) return;
    if (widget.active != old.active) {
      widget.active ? c.play() : c.pause();
    }
    if (widget.muted != old.muted) {
      c.setVolume(widget.muted ? 0 : 1);
    }
    if (widget.url != old.url) {
      _ready = false;
      c.dispose();
      _init();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggle() {
    final c = _controller;
    if (c == null) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
        _showPause = true;
      } else {
        c.play();
        _showPause = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (!_ready || c == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: widget.showControls ? _toggle : null,
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: widget.fit,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: c.value.size.width,
              height: c.value.size.height,
              child: VideoPlayer(c),
            ),
          ),
          if (_showPause)
            const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white70,
              size: 72,
            ),
        ],
      ),
    );
  }
}
