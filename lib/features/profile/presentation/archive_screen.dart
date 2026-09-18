import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/post.dart';
import '../../../widgets/async_value_view.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/profile_providers.dart';
import 'widgets/post_grid.dart';

/// Archived posts — hidden from the profile grid but kept for the owner.
class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Bài lưu trữ')),
      body: uid == null
          ? const SizedBox.shrink()
          : AsyncValueView<List<Post>>(
              value: ref.watch(authoredPostsProvider(uid)),
              onRetry: () => ref.invalidate(authoredPostsProvider(uid)),
              builder: (posts) {
                final archived = posts.where((p) => p.isArchived).toList();
                return PostGrid(
                  posts: archived,
                  emptyMessage: 'Chưa có bài viết nào được lưu trữ.',
                  emptyIcon: Icons.archive_outlined,
                  onLongPress: (post) => _showRestore(context, ref, post),
                );
              },
            ),
    );
  }

  void _showRestore(BuildContext context, WidgetRef ref, Post post) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.unarchive_outlined),
          title: const Text('Khôi phục về hồ sơ'),
          onTap: () async {
            Navigator.pop(context);
            await ref
                .read(postRepositoryProvider)
                .setArchived(post.postId, false);
          },
        ),
      ),
    );
  }
}
