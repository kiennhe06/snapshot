import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';

/// Inline voice-note player: a play/pause control, a progress bar and the
/// elapsed / total time. Each bubble owns its own [AudioPlayer].
class VoiceBubble extends StatefulWidget {
  const VoiceBubble({
    super.key,
    required this.url,
    required this.durationMs,
    required this.mine,
  });

  final String url;
  final int durationMs;
  final bool mine;

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> {
  final _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _total = Duration(milliseconds: widget.durationMs);
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted && d > Duration.zero) setState(() => _total = d);
    });
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = Duration.zero);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.mine ? Colors.white : AppColors.textPrimary;
    final track = widget.mine
        ? Colors.white.withValues(alpha: 0.35)
        : AppColors.borderStrong;
    final fill = widget.mine ? Colors.white : AppColors.primary;
    final progress = _total.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);

    return SizedBox(
      width: 190,
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Icon(
              _playing
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              size: 34,
              color: fg,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: track,
                    valueColor: AlwaysStoppedAnimation(fill),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _fmt(_playing || _position > Duration.zero
                      ? _position
                      : _total),
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.85),
                    fontSize: AppType.small,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
