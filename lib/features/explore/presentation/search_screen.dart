import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Tìm kiếm...',
              border: InputBorder.none,
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Người dùng'),
              Tab(text: 'Hashtag'),
              Tab(text: 'Địa điểm'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _UserResults(query: _query),
            _PostResults(
              provider: hashtagSearchProvider(_query),
              query: _query,
            ),
            _PostResults(
              provider: locationSearchProvider(_query),
              query: _query,
            ),
          ],
        ),
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
      return const Center(child: Text('Nhập tên hoặc username để tìm.'));
    }
    final result = ref.watch(userSearchProvider(query));
    return result.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('Lỗi tìm kiếm.')),
      data: (users) {
        if (users.isEmpty) {
          return const Center(child: Text('Không tìm thấy người dùng.'));
        }
        return ListView(
          children: users.map((u) => _userTile(context, u)).toList(),
        );
      },
    );
  }

  Widget _userTile(BuildContext context, AppUser u) => ListTile(
    leading: CircleAvatar(
      backgroundImage: u.photoUrl != null
          ? CachedNetworkImageProvider(u.photoUrl!)
          : null,
      child: u.photoUrl == null ? const Icon(Icons.person) : null,
    ),
    title: Text('@${u.username}'),
    subtitle: Text(u.displayName),
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
      return const Center(child: Text('Nhập từ khoá để tìm.'));
    }
    final result = ref.watch(provider);
    return result.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('Lỗi tìm kiếm.')),
      data: (posts) {
        if (posts.isEmpty) {
          return const Center(child: Text('Không có kết quả.'));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: posts.length,
          itemBuilder: (_, i) {
            final p = posts[i];
            return GestureDetector(
              onTap: () => context.push('${Routes.userProfile}/${p.authorId}'),
              child: CachedNetworkImage(
                imageUrl: p.coverUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: Colors.black12),
                errorWidget: (_, _, _) => const Icon(Icons.broken_image),
              ),
            );
          },
        );
      },
    );
  }
}
