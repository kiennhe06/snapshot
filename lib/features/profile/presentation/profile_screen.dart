import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../models/app_user.dart';
import '../../../models/post.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/empty_view.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/profile_providers.dart';
import 'widgets/post_grid.dart';
import 'widgets/profile_header.dart';

/// Profile screen. When [uid] is null it shows the signed-in user's profile.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.uid});

  final String? uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final profileUid = uid ?? myUid;
    if (profileUid == null) {
      return const Scaffold(body: EmptyView(message: 'Bạn chưa đăng nhập.'));
    }
    final isMe = profileUid == myUid;

    return Scaffold(
      appBar: AppBar(
        title: _TitleUsername(uid: profileUid),
        actions: [
          if (isMe) ...[
            IconButton(
              icon: const Icon(Icons.add_box_outlined),
              tooltip: 'Đăng bài',
              onPressed: () => context.push(Routes.createPost),
            ),
            _SettingsMenu(uid: profileUid),
          ],
        ],
      ),
      body: AsyncValueView<AppUser?>(
        value: ref.watch(userProfileProvider(profileUid)),
        onRetry: () => ref.invalidate(userProfileProvider(profileUid)),
        builder: (user) {
          if (user == null) {
            return const EmptyView(message: 'Không tìm thấy người dùng.');
          }
          return _ProfileBody(user: user, isMe: isMe);
        },
      ),
    );
  }
}

class _TitleUsername extends ConsumerWidget {
  const _TitleUsername({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider(uid)).valueOrNull;
    final name = user?.username.isNotEmpty == true
        ? '@${user!.username}'
        : (user?.displayName ?? 'Hồ sơ');
    return Text(name);
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.user, required this.isMe});

  final AppUser user;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(authoredPostsProvider(user.uid));
    final isFollowing =
        ref.watch(isFollowingProvider(user.uid)).valueOrNull ?? false;

    // Private gating: only owner or followers can see posts.
    final locked = !isMe && user.isPrivate && !isFollowing;

    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        headerSliverBuilder: (_, _) => [
          SliverToBoxAdapter(
            child: ProfileHeader(
              user: user,
              isMe: isMe,
              postsCount:
                  postsAsync.valueOrNull?.where((p) => !p.isArchived).length ??
                  user.postsCount,
              isFollowing: isFollowing,
              onEditProfile: () => context.push(Routes.editProfile),
              onToggleFollow: () => _toggleFollow(ref, isFollowing),
              onShowQr: () =>
                  context.push('${Routes.qrNametag}?uid=${user.uid}'),
            ),
          ),
          if (!locked)
            const SliverToBoxAdapter(
              child: TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.grid_on)),
                  Tab(icon: Icon(Icons.movie_outlined)),
                  Tab(icon: Icon(Icons.person_pin_outlined)),
                ],
              ),
            ),
        ],
        body: locked
            ? const EmptyView(
                message:
                    'Đây là tài khoản riêng tư.\nHãy theo dõi để xem bài viết.',
                icon: Icons.lock_outline,
              )
            : AsyncValueView<List<Post>>(
                value: postsAsync,
                onRetry: () => ref.invalidate(authoredPostsProvider(user.uid)),
                builder: (posts) =>
                    _ProfileTabs(authorUid: user.uid, isMe: isMe, posts: posts),
              ),
      ),
    );
  }

  Future<void> _toggleFollow(WidgetRef ref, bool isFollowing) async {
    final myUid = ref.read(authStateProvider).valueOrNull?.uid;
    if (myUid == null) return;
    final repo = ref.read(followRepositoryProvider);
    if (isFollowing) {
      await repo.unfollow(currentUid: myUid, targetUid: user.uid);
    } else {
      await repo.follow(currentUid: myUid, targetUid: user.uid);
    }
  }
}

class _ProfileTabs extends ConsumerWidget {
  const _ProfileTabs({
    required this.authorUid,
    required this.isMe,
    required this.posts,
  });

  final String authorUid;
  final bool isMe;
  final List<Post> posts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = posts.where((p) => !p.isArchived).toList();
    final pinned = active.where((p) => p.isPinned).toList()
      ..sort((a, b) => (a.pinnedOrder ?? 0).compareTo(b.pinnedOrder ?? 0));
    final reels = active.where((p) => p.isVideo).toList();
    final tagged = ref.watch(taggedPostsProvider(authorUid)).valueOrNull ?? [];

    void onLongPress(Post post) {
      if (isMe) _showPostActions(context, ref, post);
    }

    return TabBarView(
      children: [
        // Grid: pinned row on top, then all active posts.
        CustomScrollView(
          slivers: [
            if (pinned.isNotEmpty)
              SliverToBoxAdapter(child: _PinnedRow(posts: pinned)),
            SliverFillRemaining(
              hasScrollBody: true,
              child: PostGrid(
                posts: active,
                emptyMessage: isMe
                    ? 'Chưa có bài viết. Nhấn + để đăng bài đầu tiên.'
                    : 'Chưa có bài viết nào.',
                onTap: (p) => _showPostViewer(context, p),
                onLongPress: onLongPress,
              ),
            ),
          ],
        ),
        PostGrid(
          posts: reels,
          emptyMessage: 'Chưa có video/reels nào.',
          emptyIcon: Icons.movie_outlined,
          onTap: (p) => _showPostViewer(context, p),
          onLongPress: onLongPress,
        ),
        PostGrid(
          posts: tagged,
          emptyMessage: 'Chưa có bài viết được gắn thẻ.',
          emptyIcon: Icons.person_pin_outlined,
          onTap: (p) => _showPostViewer(context, p),
        ),
      ],
    );
  }

  void _showPostActions(BuildContext context, WidgetRef ref, Post post) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                post.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
              title: Text(
                post.isPinned ? 'Bỏ ghim' : 'Ghim lên hồ sơ (tối đa 3)',
              ),
              onTap: () async {
                Navigator.pop(context);
                final repo = ref.read(postRepositoryProvider);
                try {
                  if (post.isPinned) {
                    await repo.unpin(post.postId);
                  } else {
                    await repo.pin(authorUid, post.postId);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e is StateError ? e.message : 'Lỗi'),
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Lưu trữ bài viết'),
              onTap: () async {
                Navigator.pop(context);
                await ref
                    .read(postRepositoryProvider)
                    .setArchived(post.postId, true);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPostViewer(BuildContext context, Post post) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CachedNetworkImage(imageUrl: post.coverUrl, fit: BoxFit.cover),
            if (post.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(post.caption),
              ),
          ],
        ),
      ),
    );
  }
}

class _PinnedRow extends StatelessWidget {
  const _PinnedRow({required this.posts});
  final List<Post> posts;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          const Icon(Icons.push_pin, size: 16),
          const SizedBox(width: 8),
          const Text('Đã ghim'),
          const Spacer(),
          ...posts
              .take(3)
              .map(
                (p) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: p.coverUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Settings popup on the owner's profile.
class _SettingsMenu extends ConsumerWidget {
  const _SettingsMenu({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu),
      onSelected: (value) async {
        switch (value) {
          case 'archive':
            context.push(Routes.archive);
          case 'change-password':
            context.push(Routes.changePassword);
          case 'private':
            final user = ref.read(userProfileProvider(uid)).valueOrNull;
            if (user != null) {
              await ref
                  .read(userRepositoryProvider)
                  .setPrivate(uid, !user.isPrivate);
            }
          case 'login-history':
            context.push(Routes.loginHistory);
          case '2fa':
            context.push(Routes.mfaEnroll);
          case 'sign-out':
            await ref.read(authServiceProvider).signOut();
        }
      },
      itemBuilder: (context) {
        final user = ref.read(userProfileProvider(uid)).valueOrNull;
        final isPrivate = user?.isPrivate ?? false;
        return [
          const PopupMenuItem(value: 'archive', child: Text('Bài lưu trữ')),
          const PopupMenuItem(
            value: 'change-password',
            child: Text('Đổi mật khẩu'),
          ),
          PopupMenuItem(
            value: 'private',
            child: Text(
              isPrivate ? 'Chuyển sang công khai' : 'Chuyển sang riêng tư',
            ),
          ),
          const PopupMenuItem(value: '2fa', child: Text('Bật 2FA')),
          const PopupMenuItem(
            value: 'login-history',
            child: Text('Lịch sử đăng nhập'),
          ),
          const PopupMenuItem(value: 'sign-out', child: Text('Đăng xuất')),
        ];
      },
    );
  }
}
