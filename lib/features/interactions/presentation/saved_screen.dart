import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/post.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/components/components.dart';
import '../../../widgets/empty_view.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/save_repository.dart';
import '../providers/interaction_providers.dart';

/// Saved posts (bookmarks), filterable by collection.
class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  String? _collectionId; // null = all

  @override
  Widget build(BuildContext context) {
    final collections = ref.watch(collectionsProvider).valueOrNull ?? const [];
    final savedAsync = ref.watch(savedPostsProvider(_collectionId));

    return AppScaffold(
      topBar: AppTopBar(
        title: tr('Đã lưu', 'Saved'),
        showBack: true,
        actions: [
          AppIconButton(
            icon: Icons.create_new_folder_outlined,
            tooltip: tr('Tạo bộ sưu tập', 'Create collection'),
            onTap: _createCollection,
          ),
        ],
      ),
      body: Column(
        children: [
          if (collections.isNotEmpty) _collectionChips(collections),
          Expanded(
            child: AsyncValueView<List<Post>>(
              value: savedAsync,
              onRetry: () => ref.invalidate(savedPostsProvider(_collectionId)),
              builder: (posts) {
                final content = posts.isEmpty
                    ? EmptyView(
                        message: tr(
                          'Chưa có bài viết nào được lưu.',
                          'No saved posts yet.',
                        ),
                        icon: Icons.bookmark_border_rounded,
                      )
                    : _grid(posts);
                return RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.layer2,
                  onRefresh: () async =>
                      ref.invalidate(savedPostsProvider(_collectionId)),
                  child: content,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _collectionChips(List<SaveCollection> collections) {
    Widget chip(String label, String? id) {
      final active = id == _collectionId;
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: PressScale(
          onTap: () => setState(() => _collectionId = id),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.layer3,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : AppColors.textSecondary,
                fontSize: AppType.label,
                fontWeight: AppType.medium,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          chip(tr('Tất cả', 'All'), null),
          for (final c in collections) chip(c.name, c.id),
        ],
      ),
    );
  }

  Widget _grid(List<Post> posts) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemCount: posts.length,
      itemBuilder: (_, i) {
        final p = posts[i];
        return PressScale(
          onTap: () => context.push('${Routes.userProfile}/${p.authorId}'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: CachedNetworkImage(
              imageUrl: p.coverUrl,
              memCacheWidth: 400,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: AppColors.layer3),
              errorWidget: (_, _, _) => Container(
                color: AppColors.layer3,
                alignment: Alignment.center,
                child: Icon(
                  Icons.broken_image_rounded,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _createCollection() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.xxl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.layer1,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadows.overlay,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('Tạo bộ sưu tập', 'Create collection'),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppType.title,
                  fontWeight: AppType.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: controller,
                label: tr('Tên bộ sưu tập', 'Collection name'),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: tr('Tạo', 'Create'),
                onPressed: () async {
                  final name = controller.text.trim();
                  final u = ref.read(authStateProvider).valueOrNull?.uid;
                  if (name.isNotEmpty && u != null) {
                    await ref
                        .read(saveRepositoryProvider)
                        .createCollection(uid: u, name: name);
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
