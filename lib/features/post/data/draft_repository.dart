import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/post_draft.dart';

/// Persists post drafts locally (SharedPreferences). Drafts are per-device.
class DraftRepository {
  static const String _key = 'post_drafts_v1';

  Future<List<PostDraft>> getDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final drafts = list
          .map((e) => PostDraft.fromMap(e as Map<String, dynamic>))
          .toList();
      drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return drafts;
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveDraft(PostDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    final drafts = await getDrafts();
    final next = <PostDraft>[draft, ...drafts.where((d) => d.id != draft.id)];
    await prefs.setString(
      _key,
      jsonEncode(next.map((d) => d.toMap()).toList()),
    );
  }

  Future<void> deleteDraft(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final drafts = await getDrafts();
    final next = drafts.where((d) => d.id != id).toList();
    await prefs.setString(
      _key,
      jsonEncode(next.map((d) => d.toMap()).toList()),
    );
  }
}
