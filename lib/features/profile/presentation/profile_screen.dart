import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/widgets/components/components.dart';
import '../../../core/constants.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/app_user.dart';
import '../../../models/post.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/empty_view.dart';
import '../../auth/providers/auth_providers.dart';
import '../../feed/presentation/widgets/post_card.dart';
import '../../stories/presentation/widgets/highlights_row.dart';
import '../providers/profile_providers.dart';
import 'profile_menu_sheet.dart';
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
      return AppScaffold(
        body: EmptyView(
          message: tr('Bạn chưa đăng nhập.', 'You are not signed in.'),
        ),
      );
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
              tooltip: tr('Đăng bài', 'New post'),
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
            return EmptyView(
              message: tr('Không tìm thấy người dùng.', 'User not found.'),
            );
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
        : (user?.displayName ?? tr('Hồ sơ', 'Profile'));
    return Text(
      name,
      style: TextStyle(
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

    // The scroll-away header: avatar/stats/bio + story highlights. Shared by
    // both the locked view and the tabbed view so it collapses on scroll.
    final header = Column(
      mainAxisSize: MainAxisSize.min,
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
          onChangeAvatar: () => _changeAvatar(context, ref),
        ),
        HighlightsRow(uid: user.uid, isMe: isMe),
      ],
    );

    if (locked) {
      return ListView(
        children: [
          header,
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: EmptyView(
              message: tr(
                'Đây là tài khoản riêng tư.\nHãy theo dõi để xem bài viết.',
                'This account is private.\nFollow to see their posts.',
              ),
              icon: Icons.lock_outline_rounded,
            ),
          ),
        ],
      );
    }

    return AsyncValueView<List<Post>>(
      value: postsAsync,
      onRetry: () => ref.invalidate(authoredPostsProvider(user.uid)),
      builder: (posts) {
        // Followers-only posts are hidden from non-followers.
        final canSeeFollowersOnly = isMe || isFollowing;
        final vis = canSeeFollowersOnly
            ? posts
            : posts.where((p) => !p.isFollowersOnly).toList();
        return _ProfileTabs(
          authorUid: user.uid,
          isMe: isMe,
          posts: vis,
          header: header,
        );
      },
    );
  }

  /// Picks a photo from the gallery, uploads it, and saves it as the new
  /// avatar. Runs entirely from the profile screen so the owner can change
  /// their picture with a single tap on the avatar.
  Future<void> _changeAvatar(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (picked == null) return;

    if (context.mounted) {
      showAppToast(context, tr('Đang tải ảnh lên…', 'Uploading photo…'));
    }
    try {
      final photoUrl = await ref
          .read(storageServiceProvider)
          .uploadAvatar(uid, File(picked.path));
      await ref
          .read(userRepositoryProvider)
          .updateProfile(uid: uid, photoUrl: photoUrl);
      if (context.mounted) {
        showAppToast(
          context,
          tr('Đã cập nhật ảnh đại diện.', 'Profile photo updated.'),
        );
      }
    } catch (_) {
      if (context.mounted) {
        showAppToast(
          context,
          tr(
            'Không tải được ảnh. Vui lòng thử lại.',
            'Could not upload photo. Please try again.',
          ),
          type: AppToastType.error,
        );
      }
    }
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
    required this.header,
  });

  final String authorUid;
  final bool isMe;
  final List<Post> posts;

  /// Scroll-away header (avatar/bio + highlights) shown above the pinned tabs.
  final Widget header;

  @override
  ConsumerState<_ProfileTabs> createState() => _ProfileTabsState();
}

class _ProfileTabsState extends ConsumerState<_ProfileTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    // Keep the active-tab underline in sync with taps and swipes.
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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

    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        // Avatar / bio / highlights — scrolls away as the grid scrolls up.
        SliverToBoxAdapter(child: widget.header),
        // The media tabs stay pinned below the collapsed header.
        SliverOverlapAbsorber(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          sliver: SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              AppIconTabs(
                index: _controller.index,
                icons: const [
                  Icons.grid_on_rounded,
                  Icons.movie_outlined,
                  Icons.person_pin_outlined,
                ],
                onChanged: (i) => _controller.animateTo(i),
              ),
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: _controller,
        children: [
          // Grid: pinned row on top, then all active posts.
          _TabGridView(
            leading: pinned.isNotEmpty
                ? SliverToBoxAdapter(child: _PinnedRow(posts: pinned))
                : null,
            grid: SliverPostGrid(
              posts: active,
              emptyMessage: widget.isMe
                  ? tr(
                      'Chưa có bài viết. Nhấn + để đăng bài đầu tiên.',
                      'No posts yet. Tap + to share your first one.',
                    )
                  : tr('Chưa có bài viết nào.', 'No posts yet.'),
              onTap: (p) => _showPostViewer(context, p),
              onLongPress: onLongPress,
            ),
          ),
          _TabGridView(
            grid: SliverPostGrid(
              posts: reels,
              emptyMessage: tr(
                'Chưa có video/reels nào.',
                'No videos/reels yet.',
              ),
              emptyIcon: Icons.movie_outlined,
              onTap: (p) => _showPostViewer(context, p),
              onLongPress: onLongPress,
            ),
          ),
          _TabGridView(
            grid: SliverPostGrid(
              posts: tagged,
              emptyMessage: tr(
                'Chưa có bài viết được gắn thẻ.',
                'No tagged posts yet.',
              ),
              emptyIcon: Icons.person_pin_outlined,
              onTap: (p) => _showPostViewer(context, p),
            ),
          ),
        ],
      ),
    );
  }

  void _showPostActions(BuildContext context, WidgetRef ref, Post post) {
    showAppMenu(context, [
      AppMenuAction(
        icon: post.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
        label: post.isPinned
            ? tr('Bỏ ghim', 'Unpin')
            : tr('Ghim lên hồ sơ (tối đa 3)', 'Pin to profile (max 3)'),
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
              showAppToast(
                context,
                e is StateError ? e.message : tr('Lỗi', 'Error'),
                type: AppToastType.error,
              );
            }
          }
        },
      ),
      AppMenuAction(
        icon: Icons.edit_outlined,
        label: tr('Chỉnh sửa bài viết', 'Edit post'),
        onTap: () => context.push(Routes.editPost, extra: post),
      ),
      AppMenuAction(
        icon: Icons.archive_outlined,
        label: tr('Lưu trữ bài viết', 'Archive post'),
        onTap: () async {
          await ref.read(postRepositoryProvider).setArchived(post.postId, true);
        },
      ),
      AppMenuAction(
        icon: Icons.delete_outline_rounded,
        label: tr('Xoá bài viết', 'Delete post'),
        destructive: true,
        onTap: () async {
          final ok = await showAppConfirm(
            context,
            title: tr('Xoá bài viết', 'Delete post'),
            message: tr(
              'Bạn có chắc muốn xoá bài viết này?',
              'Are you sure you want to delete this post?',
            ),
            confirmLabel: tr('Xoá', 'Delete'),
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
    // Show the full post card (media, actions, caption, music chip) so a post
    // reads exactly like it does in the feed.
    showAppSheet<void>(
      context,
      builder: (_) => AppSheetSurface(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PostCard(post: post),
          ),
        ),
      ),
    );
  }
}

/// One tab's body inside the profile NestedScrollView: injects the pinned
/// header's overlap, then an optional leading sliver and the grid sliver.
class _TabGridView extends StatelessWidget {
  const _TabGridView({required this.grid, this.leading});

  final Widget grid;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        ?leading,
        grid,
      ],
    );
  }
}

/// Pinned-header delegate hosting the media tab strip with an opaque backing
/// so grid cells don't show through while it's stuck to the top.
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.child);

  final Widget child;
  static const double _height = 50;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: _height,
      color: AppColors.scaffold,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => oldDelegate.child != child;
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
          Icon(
            Icons.push_pin_rounded,
            size: AppIconSize.sm,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            tr('Đã ghim', 'Pinned'),
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
      tooltip: tr('Cài đặt', 'Settings'),
      onTap: () => _openMenu(context, ref),
    );
  }

  void _openMenu(BuildContext context, WidgetRef ref) {
    // Concept B: compact activity hub + one door into grouped Settings.
    showProfileMenu(context);
  }
}
