import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/post_draft.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/empty_view.dart';
import '../providers/post_providers.dart';
import 'create_post_screen.dart';

/// Lists locally-saved post drafts; tap to resume, swipe/long-press to delete.
class DraftsScreen extends ConsumerWidget {
  const DraftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bản nháp')),
      body: AsyncValueView<List<PostDraft>>(
        value: ref.watch(draftsProvider),
        onRetry: () => ref.invalidate(draftsProvider),
        builder: (drafts) {
          if (drafts.isEmpty) {
            return const EmptyView(
              message: 'Chưa có bản nháp nào.',
              icon: Icons.drafts_outlined,
            );
          }
          return ListView.separated(
            itemCount: drafts.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = drafts[i];
              final firstPath = d.items.isNotEmpty ? d.items.first.path : null;
              return ListTile(
                leading: firstPath != null && File(firstPath).existsSync()
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(firstPath),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.image_not_supported_outlined),
                title: Text(
                  d.caption.isEmpty ? '(Không có chú thích)' : d.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${d.items.length} mục'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await ref.read(draftRepositoryProvider).deleteDraft(d.id);
                    ref.invalidate(draftsProvider);
                  },
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreatePostScreen(draft: d),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
