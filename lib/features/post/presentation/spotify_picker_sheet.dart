import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/spotify_track.dart';
import '../../../widgets/components/components.dart';
import '../providers/spotify_providers.dart';

/// Opens the Spotify track search sheet; returns the chosen track (or null).
Future<SpotifyTrack?> showSpotifyPicker(BuildContext context) {
  return showAppSheet<SpotifyTrack>(
    context,
    builder: (_) => const _SpotifyPicker(),
  );
}

class _SpotifyPicker extends ConsumerStatefulWidget {
  const _SpotifyPicker();

  @override
  ConsumerState<_SpotifyPicker> createState() => _SpotifyPickerState();
}

class _SpotifyPickerState extends ConsumerState<_SpotifyPicker> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.read(spotifyServiceProvider).isConfigured;
    final results = _query.isEmpty
        ? const AsyncValue<List<SpotifyTrack>>.data([])
        : ref.watch(spotifySearchProvider(_query));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AppSheetSurface(
        title: tr('Thêm nhạc', 'Add music'),
        maxHeightFactor: 0.85,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: _controller,
              label: tr('Tìm bài hát trên Spotify', 'Search Spotify'),
              hint: tr('Tên bài hát hoặc nghệ sĩ...', 'Song or artist...'),
              icon: Icons.search_rounded,
              onChanged: _onChanged,
            ),
            const SizedBox(height: AppSpacing.md),
            if (!configured)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  tr(
                    'Chưa cấu hình Spotify (thiếu client secret).',
                    'Spotify not configured (missing client secret).',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textTertiary),
                ),
              )
            else
              Flexible(
                child: results.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: LoadingViewInline(),
                  ),
                  error: (_, _) => Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      tr('Không tìm được. Thử lại.', 'Search failed. Retry.'),
                      style: TextStyle(color: AppColors.textTertiary),
                    ),
                  ),
                  data: (tracks) {
                    if (_query.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          tr(
                            'Nhập tên bài hát để tìm.',
                            'Type a song to search.',
                          ),
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                      );
                    }
                    if (tracks.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          tr('Không có kết quả.', 'No results.'),
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: tracks.length,
                      itemBuilder: (_, i) => _TrackRow(
                        track: tracks[i],
                        onTap: () => Navigator.pop(context, tracks[i]),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({required this.track, required this.onTap});
  final SpotifyTrack track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppTile(
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: track.coverUrl.isEmpty
            ? Container(
                width: 44,
                height: 44,
                color: AppColors.layer3,
                child: Icon(Icons.music_note_rounded, color: AppColors.textTertiary),
              )
            : CachedNetworkImage(
                imageUrl: track.coverUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
      ),
      title: track.name,
      subtitle: track.artist,
      trailing: track.previewUrl != null
          ? Icon(Icons.play_circle_outline_rounded, color: AppColors.primary)
          : Icon(Icons.open_in_new_rounded, color: AppColors.textTertiary,
              size: AppIconSize.sm),
    );
  }
}

/// Small inline loader (avoids importing the full-screen LoadingView here).
class LoadingViewInline extends StatelessWidget {
  const LoadingViewInline({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.primary),
    ),
  );
}
