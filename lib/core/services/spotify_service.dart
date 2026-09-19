import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/spotify_track.dart';
import '../spotify_config.dart';

/// Talks to the Spotify Web API using the Client Credentials flow (app token,
/// no user login) for track search. The app token is cached until it expires.
class SpotifyService {
  SpotifyService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _token;
  DateTime? _expiresAt;

  bool get isConfigured =>
      spotifyClientSecret.isNotEmpty &&
      !spotifyClientSecret.startsWith('PASTE') &&
      spotifyClientId.isNotEmpty;

  Future<String?> _token_() async {
    if (!isConfigured) return null;
    final now = DateTime.now();
    if (_token != null && _expiresAt != null && now.isBefore(_expiresAt!)) {
      return _token;
    }
    final basic = base64Encode(
      utf8.encode('$spotifyClientId:$spotifyClientSecret'),
    );
    final resp = await _client.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Authorization': 'Basic $basic',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'grant_type': 'client_credentials'},
    );
    if (resp.statusCode != 200) return null;
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    _token = j['access_token'] as String?;
    final ttl = (j['expires_in'] as num?)?.toInt() ?? 3600;
    _expiresAt = now.add(Duration(seconds: ttl - 60));
    return _token;
  }

  /// Resolves a pasted Spotify track link via the public oEmbed endpoint —
  /// no auth, no Premium needed. Returns title + album art (no preview/artist).
  Future<SpotifyTrack?> resolveTrackUrl(String url) async {
    final u = url.trim();
    if (!u.contains('open.spotify.com/track/')) return null;
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
  }

  /// Searches tracks; returns [] when not configured or on any error.
  Future<List<SpotifyTrack>> searchTracks(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final token = await _token_();
    if (token == null) return const [];
    // market=VN restricts results to tracks available in Vietnam, biasing the
    // list toward Vietnamese songs the user actually wants.
    final resp = await _client.get(
      Uri.parse(
        'https://api.spotify.com/v1/search'
        '?type=track&limit=20&market=VN&q=${Uri.encodeQueryComponent(q)}',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode != 200) return const [];
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final items =
        ((body['tracks'] as Map<String, dynamic>?)?['items'] as List<dynamic>?) ??
        const [];
    return items
        .map((e) => SpotifyTrack.fromJson(e as Map<String, dynamic>))
        .where((t) => t.id.isNotEmpty)
        .toList();
  }
}
