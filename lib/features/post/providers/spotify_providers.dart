import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/spotify_service.dart';
import '../../../models/spotify_track.dart';

final spotifyServiceProvider = Provider<SpotifyService>(
  (ref) => SpotifyService(),
);

/// Track search results for a query (debounce at the UI layer).
final spotifySearchProvider = FutureProvider.autoDispose
    .family<List<SpotifyTrack>, String>((ref, query) {
      return ref.watch(spotifyServiceProvider).searchTracks(query);
    });

/// Resolves a pasted Spotify track link (free, via oEmbed).
final spotifyResolveProvider = FutureProvider.autoDispose
    .family<SpotifyTrack?, String>((ref, url) {
      return ref.watch(spotifyServiceProvider).resolveTrackUrl(url);
    });
