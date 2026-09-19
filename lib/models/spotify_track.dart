/// A track returned from the Spotify search API.
class SpotifyTrack {
  const SpotifyTrack({
    required this.id,
    required this.name,
    required this.artist,
    required this.coverUrl,
    required this.spotifyUrl,
    this.previewUrl,
  });

  final String id;
  final String name;
  final String artist;
  final String coverUrl;
  final String spotifyUrl;

  /// 30-second MP3 preview. Often null now — Spotify deprecated preview URLs
  /// for many apps, so callers must fall back to opening the track.
  final String? previewUrl;

  /// From an iTunes Search API song result (free, key-less, works in Vietnam;
  /// includes a 30-second preview + album art).
  factory SpotifyTrack.fromItunes(Map<String, dynamic> j) {
    final art = j['artworkUrl100'] as String? ?? '';
    return SpotifyTrack(
      id: '${j['trackId'] ?? ''}',
      name: j['trackName'] as String? ?? '',
      artist: j['artistName'] as String? ?? '',
      // Upscale the 100px thumbnail to a crisper 300px cover.
      coverUrl: art.replaceAll('100x100bb', '300x300bb'),
      previewUrl: j['previewUrl'] as String?,
      spotifyUrl: j['trackViewUrl'] as String? ?? '',
    );
  }

  factory SpotifyTrack.fromJson(Map<String, dynamic> j) {
    final artists = (j['artists'] as List<dynamic>? ?? const [])
        .map((a) => (a as Map<String, dynamic>)['name'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .join(', ');
    final images =
        ((j['album'] as Map<String, dynamic>?)?['images'] as List<dynamic>?) ??
        const [];
    return SpotifyTrack(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      artist: artists,
      // images are largest → smallest; take a mid/small one for a thumbnail.
      coverUrl: images.isEmpty
          ? ''
          : (images.last as Map<String, dynamic>)['url'] as String? ?? '',
      previewUrl: j['preview_url'] as String?,
      spotifyUrl:
          (j['external_urls'] as Map<String, dynamic>?)?['spotify'] as String? ??
          '',
    );
  }
}
