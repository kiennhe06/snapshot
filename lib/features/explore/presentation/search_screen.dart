import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/widgets/components/components.dart';
import '../../../core/constants.dart';
import '../../../models/app_user.dart';
import '../../../models/post.dart';
import '../providers/search_providers.dart';

/// Search across users, hashtags and locations.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  int _tab = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: AppTopBar(
        showBack: true,
        titleWidget: _searchField(),
        bottom: AppSegmentedTabs(
          index: _tab,
          labels: const ['Người dùng', 'Hashtag', 'Địa điểm'],
          onChanged: (i) => setState(() => _tab = i),
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _UserResults(query: _query),
          _PostResults(provider: hashtagSearchProvider(_query), query: _query),
          _PostResults(provider: locationSearchProvider(_query), query: _query),
        ],
      ),
    );
  }

  /// Rounded search pill with autofocus (styled plain [TextField], logic kept).
  Widget _searchField() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.layer3,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: AppIconSize.md,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              cursorColor: AppColors.primary,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppType.subhead,
              ),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Tìm kiếm...',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserResults extends ConsumerWidget {
  const _UserResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.isEmpty) {
      return const _Hint('Nhập tên hoặc username để tìm.');
    }
    final result = ref.watch(userSearchProvider(query));
    return result.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (_, _) => const _Hint('Lỗi tìm kiếm.'),
      data: (users) {
        if (users.isEmpty) {
          return const _Hint('Không tìm thấy người dùng.');
        }
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: users.map((u) => _userTile(context, u)).toList(),
        );
      },
    );
  }

  Widget _userTile(BuildContext context, AppUser u) => AppTile(
    leading: AppAvatar(
      imageProvider: u.photoUrl != null
          ? CachedNetworkImageProvider(u.photoUrl!)
          : null,
      radius: 22,
    ),
    title: '@${u.username}',
    subtitle: u.displayName,
    onTap: () => context.push('${Routes.userProfile}/${u.uid}'),
  );
}

class _PostResults extends ConsumerWidget {
  const _PostResults({required this.provider, required this.query});
  final ProviderListenable<AsyncValue<List<Post>>> provider;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.isEmpty) {
      return const _Hint('Nhập từ khoá để tìm.');
    }
    final result = ref.watch(provider);
    return result.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (_, _) => const _Hint('Lỗi tìm kiếm.'),
      data: (posts) {
        if (posts.isEmpty) {
          return const _Hint('Không có kết quả.');
        }
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
            return GestureDetector(
              onTap: () => context.push('${Routes.userProfile}/${p.authorId}'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: CachedNetworkImage(
                  imageUrl: p.coverUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(color: AppColors.layer3),
                  errorWidget: (_, _, _) => Container(
                    color: AppColors.layer3,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image_rounded,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Centered muted hint text for empty / error states.
class _Hint extends StatelessWidget {
  const _Hint(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: AppType.subhead,
          ),
        ),
      ),
    );
  }
}
