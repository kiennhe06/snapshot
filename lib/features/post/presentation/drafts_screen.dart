import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/widgets/components/components.dart';
import '../../../models/post_draft.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/empty_view.dart';
import '../providers/post_providers.dart';
import 'create_post_screen.dart';

/// Lists locally-saved post drafts; tap to resume, tap delete to remove.
class DraftsScreen extends ConsumerWidget {
  const DraftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      topBar: const AppTopBar(title: 'Bản nháp', showBack: true),
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
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: drafts.length,
            itemBuilder: (_, i) {
              final d = drafts[i];
              final firstPath = d.items.isNotEmpty ? d.items.first.path : null;
              final hasThumb =
                  firstPath != null && File(firstPath).existsSync();
              return AppCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: AppTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: hasThumb
                        ? Image.file(
                            File(firstPath),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 48,
                            height: 48,
                            color: AppColors.layer3,
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              color: AppColors.textTertiary,
                              size: AppIconSize.md,
                            ),
                          ),
                  ),
                  title: d.caption.isEmpty ? '(Không có chú thích)' : d.caption,
                  subtitle: '${d.items.length} mục',
                  trailing: AppIconButton(
                    icon: Icons.delete_outline,
                    tooltip: 'Xoá bản nháp',
                    color: AppColors.danger,
                    onTap: () async {
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
