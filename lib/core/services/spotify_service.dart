import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/spotify_track.dart';

/// Music search for the composer. Uses Apple's free, key-less iTunes Search API
/// (real results + a working 30-second preview + album art, available in
/// Vietnam), and the Spotify oEmbed endpoint to resolve a pasted Spotify link.
/// No credentials required.
class SpotifyService {
  SpotifyService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  bool get isConfigured => true;

  /// A handful of popular songs to show before the user types anything, so the
  /// picker never opens empty. Each seed is resolved through the same iTunes
  /// search (real cover art + a 30s preview), then de-duplicated by track id.
  static const _suggestionSeeds = <String>[
    'Chúng Ta Của Hiện Tại Sơn Tùng',
    'Nơi Này Có Anh',
    'Hãy Trao Cho Anh',
    'Người Ấy',
    'Đưa Nhau Đi Trốn',
    'Blinding Lights The Weeknd',
    'As It Was Harry Styles',
    'Flowers Miley Cyrus',
  ];

  /// Fetches the suggested tracks (top hit per seed). Returns [] on any error.
  Future<List<SpotifyTrack>> suggestedTracks() async {
    try {
      final lists = await Future.wait(
        _suggestionSeeds.map((seed) => searchTracks(seed)),
      );
      final seen = <String>{};
      final out = <SpotifyTrack>[];
      for (final list in lists) {
        // Prefer the first hit that has a playable preview.
        final track = list.firstWhere(
          (t) => t.previewUrl != null,
          orElse: () => list.isNotEmpty ? list.first : _empty,
        );
        if (track.id.isNotEmpty && seen.add(track.id)) out.add(track);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static const _empty = SpotifyTrack(
    id: '',
    name: '',
    artist: '',
    coverUrl: '',
    spotifyUrl: '',
  );

  /// Searches songs via the iTunes Search API. Returns [] on any error.
  Future<List<SpotifyTrack>> searchTracks(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    try {
      final resp = await _client.get(
        Uri.parse(
          'https://itunes.apple.com/search'
          '?media=music&entity=song&limit=25&country=VN'
          '&term=${Uri.encodeQueryComponent(q)}',
        ),
      );
      if (resp.statusCode != 200) return const [];
      final results =
          (jsonDecode(resp.body) as Map<String, dynamic>)['results']
              as List<dynamic>? ??
          const [];
      return results
          .map((e) => SpotifyTrack.fromItunes(e as Map<String, dynamic>))
          .where((t) => t.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Resolves a pasted Spotify track link via the public oEmbed endpoint —
  /// no auth. Returns title + album art (no preview/artist).
  Future<SpotifyTrack?> resolveTrackUrl(String url) async {
    final u = url.trim();
    if (!u.contains('open.spotify.com/track/')) return null;
    try {
      final resp = await _client.get(
        Uri.parse(
          'https://open.spotify.com/oembed?url=${Uri.encodeQueryComponent(u)}',
        ),
      );
      if (resp.statusCode != 200) return null;
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final id = RegExp(r'track/([A-Za-z0-9]+)').firstMatch(u)?.group(1) ?? '';
      return SpotifyTrack(
        id: id,
        name: j['title'] as String? ?? '',
        artist: '',
        coverUrl: j['thumbnail_url'] as String? ?? '',
        spotifyUrl: u.split('?').first,
      );
    } catch (_) {
      return null;
    }
  }
}
