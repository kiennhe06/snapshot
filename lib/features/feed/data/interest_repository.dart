import 'dart:math' as m;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/post.dart';

/// A lightweight, self-learning interest profile for one user, kept at
/// `users/{uid}/meta/interests`. It is just two weighted maps that grow as the
/// person interacts — no event log, no server job, no extra cost. Used to rank
/// the "For you" reels toward the authors and topics they engage with.
class InterestProfile {
  const InterestProfile({this.authors = const {}, this.hashtags = const {}});

  /// Affinity weight per author id.
  final Map<String, double> authors;

  /// Interest weight per hashtag (without '#').
  final Map<String, double> hashtags;

  bool get isEmpty => authors.isEmpty && hashtags.isEmpty;

  /// Multiplies every weight by [factor] and drops anything that falls below
  /// [floor] — used to decay old interests so fresh behaviour wins.
  InterestProfile scaled(double factor, {double floor = 0.5}) {
    Map<String, double> s(Map<String, double> src) {
      final out = <String, double>{};
      src.forEach((k, v) {
        final nv = v * factor;
        if (nv.abs() >= floor) out[k] = nv;
      });
      return out;
    }

    return InterestProfile(authors: s(authors), hashtags: s(hashtags));
  }

  /// How well a candidate post matches this profile. Higher = more relevant.
  double scoreFor(Post p) {
    var s = authors[p.authorId] ?? 0;
    for (final t in p.hashtags) {
      s += hashtags[t] ?? 0;
    }
    return s;
  }

  factory InterestProfile.fromMap(Map<String, dynamic>? j) {
    if (j == null) return const InterestProfile();
    Map<String, double> parse(Object? v) =>
        (v as Map<dynamic, dynamic>? ?? const {}).map(
          (k, val) => MapEntry(k as String, (val as num?)?.toDouble() ?? 0),
        );
    return InterestProfile(
      authors: parse(j['authors']),
      hashtags: parse(j['hashtags']),
    );
  }
}

/// Reads and incrementally updates the per-user [InterestProfile].
class InterestRepository {
  InterestRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid).collection('meta').doc('interests');

  // Time decay: every few days the whole profile is scaled down, so stale
  // interests fade and new trends surface faster. Applied lazily on read.
  static const int _decayEveryDays = 3;
  static const double _decayFactor = 0.8;

  Future<InterestProfile> get(String uid) async {
    final snap = await _doc(uid).get();
    final data = snap.data();
    if (data == null) return const InterestProfile();
    var profile = InterestProfile.fromMap(data);
    if (profile.isEmpty) return profile;

    final decayedAt = (data['decayedAt'] as Timestamp?)?.toDate();
    final days = decayedAt == null
        ? 0
        : DateTime.now().difference(decayedAt).inDays;
    if (decayedAt == null || days >= _decayEveryDays) {
      final factor = decayedAt == null
          ? 1.0
          : m.pow(_decayFactor, days / _decayEveryDays).toDouble();
      if (factor < 1.0) profile = profile.scaled(factor);
      // Persist the decayed weights + reset the clock (full overwrite so
      // pruned keys are removed). Fire-and-forget.
      _doc(uid).set({
        'authors': profile.authors,
        'hashtags': profile.hashtags,
        'decayedAt': FieldValue.serverTimestamp(),
      }).catchError((_) {});
    }
    return profile;
  }

  /// Adds [weight] to the author and hashtags of [post]. Deep-merges with
  /// `FieldValue.increment`, so it also creates the doc on first use.
  Future<void> record({
    required String uid,
    required Post post,
    required double weight,
  }) {
    final authors = <String, Object>{};
    if (post.authorId.isNotEmpty && post.authorId != uid) {
      authors[post.authorId] = FieldValue.increment(weight);
    }
    final tags = <String, Object>{};
    for (final t in post.hashtags.take(8)) {
      tags[t] = FieldValue.increment(weight);
    }
    return _write(uid, authors, tags);
  }

  /// Adds [weight] to a single author (positive or negative) — e.g. a negative
  /// bump when the user dismisses a suggested account.
  Future<void> bumpAuthor({
    required String uid,
    required String authorId,
    required double weight,
  }) {
    if (authorId.isEmpty || authorId == uid) return Future.value();
    return _write(uid, {authorId: FieldValue.increment(weight)}, const {});
  }

  Future<void> _write(
    String uid,
    Map<String, Object> authors,
    Map<String, Object> tags,
  ) {
    final data = <String, Object>{};
    if (authors.isNotEmpty) data['authors'] = authors;
    if (tags.isNotEmpty) data['hashtags'] = tags;
    if (data.isEmpty) return Future.value();
    // Signal tracking must never surface an error to the user.
    return _doc(uid).set(data, SetOptions(merge: true)).catchError((_) {});
  }
}

/// Signal weights — stronger intent earns a bigger bump (and faster learning).
abstract class InterestWeight {
  static const double view = 1; // a reel scrolled into view
  static const double comment = 2;
  static const double share = 2;
  static const double like = 3;
  static const double save = 4;
  static const double follow = 6;
  static const double dismiss = -4; // "not interested" in a suggested account
}

/// Ranks candidate posts by interest score, keeping a little freshness and a
/// touch of popularity so a brand-new profile still gets a sensible order and
/// the feed does not collapse onto a single author.
List<Post> rankByInterest(List<Post> posts, InterestProfile profile) {
  if (posts.isEmpty) return posts;
  final now = DateTime.now();
  double score(Post p) {
    final interest = profile.scoreFor(p);
    // Recency: ~1.0 today fading over a week.
    final ageDays = now.difference(p.createdAt).inHours / 24.0;
    final recency = 1.0 / (1.0 + (ageDays / 7.0));
    // Popularity: gentle, log-less cap so it never dominates interest.
    final popularity = (p.likesCount.clamp(0, 50)) / 50.0;
    return interest * 3.0 + recency * 1.5 + popularity * 0.8;
  }

  final ranked = [...posts]..sort((a, b) => score(b).compareTo(score(a)));
  return ranked;
}

/// Gentle re-rank for the Home (Following) timeline: recency stays dominant so
/// the feed still reads as "newest first", with only a small nudge toward the
/// authors/topics the viewer engages with.
List<Post> rankFeed(List<Post> posts, InterestProfile profile) {
  if (posts.isEmpty || profile.isEmpty) return posts;
  final now = DateTime.now();
  double score(Post p) {
    final ageHours = now.difference(p.createdAt).inHours.toDouble();
    final recency = 1.0 / (1.0 + ageHours / 24.0);
    return recency * 3.0 + profile.scoreFor(p) * 0.5;
  }

  return [...posts]..sort((a, b) => score(b).compareTo(score(a)));
}
