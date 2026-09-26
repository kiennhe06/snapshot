import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/spotify_track.dart';
import '../../../widgets/components/components.dart';

/// What the user chose to do from the track detail sheet.
enum TrackDetailAction { change, remove }

/// Shows a rich detail view for a selected [track]: large cover art, title,
/// artist, a 30-second preview player, and actions to swap or remove the song.
Future<TrackDetailAction?> showTrackDetail(
  BuildContext context,
  SpotifyTrack track,
) {
  return showAppSheet<TrackDetailAction>(
    context,
    builder: (_) => _TrackDetailSheet(track: track),
  );
}

class _TrackDetailSheet extends StatefulWidget {
  const _TrackDetailSheet({required this.track});
  final SpotifyTrack track;

  @override
  State<_TrackDetailSheet> createState() => _TrackDetailSheetState();
}

class _TrackDetailSheetState extends State<_TrackDetailSheet> {
  final _audio = AudioPlayer();
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _audio.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  Future<void> _togglePreview() async {
    final preview = widget.track.previewUrl;
    if (preview == null) return;
    if (_playing) {
      await _audio.pause();
      if (mounted) setState(() => _playing = false);
    } else {
      await _audio.play(UrlSource(preview));
      if (mounted) setState(() => _playing = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final hasPreview = track.previewUrl != null;

    return AppSheetSurface(
      title: tr('Chi tiết bài hát', 'Song details'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Large cover art with a play/pause preview overlay.
          Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: track.coverUrl.isEmpty
                    ? Container(
                        width: 180,
                        height: 180,
                        color: AppColors.layer3,
                        child: Icon(
                          Icons.music_note_rounded,
                          size: 64,
                          color: AppColors.textTertiary,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: track.coverUrl,
                        width: 180,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
              ),
              if (hasPreview)
                PressScale(
                  onTap: _togglePreview,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.55),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      _playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            track.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.h1,
          ),
          if (track.artist.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              track.artist,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppType.subhead,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            hasPreview
                ? tr('Nhấn để nghe thử 30 giây', 'Tap to preview 30 seconds')
                : tr('Không có bản nghe thử', 'No preview available'),
            style: AppText.caption,
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: tr('Đổi bài khác', 'Change song'),
                  variant: AppButtonVariant.secondary,
                  icon: Icons.swap_horiz_rounded,
                  onPressed: () =>
                      Navigator.pop(context, TrackDetailAction.change),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: tr('Gỡ nhạc', 'Remove'),
                  variant: AppButtonVariant.ghost,
                  icon: Icons.close_rounded,
                  onPressed: () =>
                      Navigator.pop(context, TrackDetailAction.remove),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
