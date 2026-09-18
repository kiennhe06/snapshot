import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/widgets/components/components.dart';
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
      return const AppScaffold(body: EmptyView(message: 'Bạn chưa đăng nhập.'));
    }
    final isMe = profileUid == myUid;

    return AppScaffold(
      topBar: AppTopBar(
        titleWidget: _TitleUsername(uid: profileUid),
        showBack: !isMe,
        actions: [
          if (isMe) ...[
            AppIconButton(
              icon: Icons.add_box_outlined,
              tooltip: 'Đăng bài',
              onTap: () => context.push(Routes.createPost),
            ),
            _SettingsButton(uid: profileUid),
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
    return Text(
      name,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: AppType.title,
        fontWeight: AppType.bold,
        letterSpacing: -0.2,
      ),
    );
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

    return Column(
      children: [
        ProfileHeader(
          user: user,
          isMe: isMe,
          postsCount:
              postsAsync.valueOrNull?.where((p) => !p.isArchived).length ??
              user.postsCount,
          isFollowing: isFollowing,
          onEditProfile: () => context.push(Routes.editProfile),
          onToggleFollow: () => _toggleFollow(ref, isFollowing),
          onShowQr: () => context.push('${Routes.qrNametag}?uid=${user.uid}'),
        ),
        if (locked)
          const Expanded(
            child: EmptyView(
              message:
                  'Đây là tài khoản riêng tư.\nHãy theo dõi để xem bài viết.',
              icon: Icons.lock_outline_rounded,
            ),
          )
        else
          Expanded(
            child: AsyncValueView<List<Post>>(
              value: postsAsync,
              onRetry: () => ref.invalidate(authoredPostsProvider(user.uid)),
              builder: (posts) =>
                  _ProfileTabs(authorUid: user.uid, isMe: isMe, posts: posts),
            ),
          ),
      ],
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

class _ProfileTabs extends ConsumerStatefulWidget {
  const _ProfileTabs({
    required this.authorUid,
    required this.isMe,
    required this.posts,
  });

  final String authorUid;
  final bool isMe;
  final List<Post> posts;

  @override
  ConsumerState<_ProfileTabs> createState() => _ProfileTabsState();
}

class _ProfileTabsState extends ConsumerState<_ProfileTabs> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final active = widget.posts.where((p) => !p.isArchived).toList();
    final pinned = active.where((p) => p.isPinned).toList()
      ..sort((a, b) => (a.pinnedOrder ?? 0).compareTo(b.pinnedOrder ?? 0));
    final reels = active.where((p) => p.isVideo).toList();
    final tagged =
        ref.watch(taggedPostsProvider(widget.authorUid)).valueOrNull ?? [];

    void onLongPress(Post post) {
      if (widget.isMe) _showPostActions(context, ref, post);
    }

    return Column(
      children: [
        AppIconTabs(
          index: _tab,
          icons: const [
            Icons.grid_on_rounded,
            Icons.movie_outlined,
            Icons.person_pin_outlined,
          ],
          onChanged: (i) => setState(() => _tab = i),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
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
                      emptyMessage: widget.isMe
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
          ),
        ),
      ],
    );
  }

  void _showPostActions(BuildContext context, WidgetRef ref, Post post) {
    showAppMenu(context, [
      AppMenuAction(
        icon: post.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
        label: post.isPinned ? 'Bỏ ghim' : 'Ghim lên hồ sơ (tối đa 3)',
        onTap: () async {
          final repo = ref.read(postRepositoryProvider);
          try {
            if (post.isPinned) {
              await repo.unpin(post.postId);
            } else {
              await repo.pin(widget.authorUid, post.postId);
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e is StateError ? e.message : 'Lỗi')),
              );
            }
          }
        },
      ),
      AppMenuAction(
        icon: Icons.edit_outlined,
        label: 'Chỉnh sửa bài viết',
        onTap: () => context.push(Routes.editPost, extra: post),
      ),
      AppMenuAction(
        icon: Icons.archive_outlined,
        label: 'Lưu trữ bài viết',
        onTap: () async {
          await ref.read(postRepositoryProvider).setArchived(post.postId, true);
        },
      ),
      AppMenuAction(
        icon: Icons.delete_outline_rounded,
        label: 'Xoá bài viết',
        destructive: true,
        onTap: () async {
          final ok = await showAppConfirm(
            context,
            title: 'Xoá bài viết',
            message: 'Bạn có chắc muốn xoá bài viết này?',
            confirmLabel: 'Xoá',
            destructive: true,
          );
          if (ok) {
            await ref.read(postRepositoryProvider).deletePost(post.postId);
          }
        },
      ),
    ]);
  }

  void _showPostViewer(BuildContext context, Post post) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.xxl),
        child: AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CachedNetworkImage(imageUrl: post.coverUrl, fit: BoxFit.cover),
              if (post.caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    post.caption,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppType.subhead,
                      height: 1.35,
                    ),
                  ),
                ),
            ],
          ),
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
      color: AppColors.layer3,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          const Icon(
            Icons.push_pin_rounded,
            size: AppIconSize.sm,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          const Text(
            'Đã ghim',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppType.body,
              fontWeight: AppType.medium,
            ),
          ),
          const Spacer(),
          ...posts
              .take(3)
              .map(
                (p) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xxs),
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

/// Settings action on the owner's profile (opens a rounded action sheet).
class _SettingsButton extends ConsumerWidget {
  const _SettingsButton({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppIconButton(
      icon: Icons.menu_rounded,
      tooltip: 'Cài đặt',
      onTap: () => _openMenu(context, ref),
    );
  }

  void _openMenu(BuildContext context, WidgetRef ref) {
    final user = ref.read(userProfileProvider(uid)).valueOrNull;
    final isPrivate = user?.isPrivate ?? false;
    showAppMenu(context, [
      AppMenuAction(
        icon: Icons.edit_note_rounded,
        label: 'Bản nháp',
        onTap: () => context.push(Routes.drafts),
      ),
      AppMenuAction(
        icon: Icons.archive_outlined,
        label: 'Bài lưu trữ',
        onTap: () => context.push(Routes.archive),
      ),
      AppMenuAction(
        icon: Icons.lock_reset_rounded,
        label: 'Đổi mật khẩu',
        onTap: () => context.push(Routes.changePassword),
      ),
      AppMenuAction(
        icon: isPrivate ? Icons.public_rounded : Icons.lock_outline_rounded,
        label: isPrivate ? 'Chuyển sang công khai' : 'Chuyển sang riêng tư',
        onTap: () async {
          final u = ref.read(userProfileProvider(uid)).valueOrNull;
          if (u != null) {
            await ref
                .read(userRepositoryProvider)
                .setPrivate(uid, !u.isPrivate);
          }
        },
      ),
      AppMenuAction(
        icon: Icons.shield_outlined,
        label: 'Bật 2FA',
        onTap: () => context.push(Routes.mfaEnroll),
      ),
      AppMenuAction(
        icon: Icons.history_rounded,
        label: 'Lịch sử đăng nhập',
        onTap: () => context.push(Routes.loginHistory),
      ),
      AppMenuAction(
        icon: Icons.logout_rounded,
        label: 'Đăng xuất',
        destructive: true,
        onTap: () async {
          await ref.read(authServiceProvider).signOut();
        },
      ),
    ]);
  }
}
