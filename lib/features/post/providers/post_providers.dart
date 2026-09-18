import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/post_draft.dart';
import '../data/draft_repository.dart';

final draftRepositoryProvider = Provider<DraftRepository>(
  (ref) => DraftRepository(),
);

/// Locally saved post drafts, newest first.
final draftsProvider = FutureProvider.autoDispose<List<PostDraft>>((ref) {
  return ref.watch(draftRepositoryProvider).getDrafts();
});
