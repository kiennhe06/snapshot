import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/app_user.dart';
import '../../../models/post.dart';

/// Search across users, hashtags and locations, plus follow suggestions.
/// All queries use only automatic single-field / array-contains indexes.
class SearchRepository {
  SearchRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Prefix search on username (case-insensitive; usernames are stored lower).
  Future<List<AppUser>> searchUsers(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final snap = await _db
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: q)
        .where('username', isLessThan: '$q')
        .limit(20)
        .get();
    return snap.docs.map((d) => AppUser.fromMap(d.data())).toList();
  }

  /// Posts carrying a given hashtag (exact tag, without '#').
  Future<List<Post>> searchHashtag(String tag) async {
    final t = tag.trim().toLowerCase().replaceAll('#', '');
    if (t.isEmpty) return const [];
    final snap = await _db
        .collection('posts')
        .where('hashtags', arrayContains: t)
        .limit(40)
        .get();
    final posts = snap.docs
        .map((d) => Post.fromMap(d.data()))
        .where((p) => !p.isArchived)
        .toList();
    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  /// Prefix search on a post's location.
  Future<List<Post>> searchLocation(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final snap = await _db
        .collection('posts')
        .where('location', isGreaterThanOrEqualTo: q)
        .where('location', isLessThan: '$q')
        .limit(40)
        .get();
    return snap.docs
        .map((d) => Post.fromMap(d.data()))
        .where((p) => !p.isArchived)
        .toList();
  }

  /// Suggested users to follow: most-followed accounts, excluding self and the
  /// people the user already follows.
  Future<List<AppUser>> suggestedUsers({
    required String currentUid,
    required List<String> followingIds,
    int limit = 20,
  }) async {
    final snap = await _db
        .collection('users')
        .orderBy('followersCount', descending: true)
        .limit(50)
        .get();
    final exclude = {currentUid, ...followingIds};
    return snap.docs
        .map((d) => AppUser.fromMap(d.data()))
        .where((u) => !exclude.contains(u.uid))
        .take(limit)
        .toList();
  }
}
