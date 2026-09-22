import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/app_user.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/components/components.dart';
import '../../../widgets/empty_view.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/profile_providers.dart';

/// Followers / Following list for a profile, with a follow button per row.
class FollowListScreen extends ConsumerStatefulWidget {
  const FollowListScreen({
    super.key,
    required this.uid,
    required this.username,
    this.showFollowers = true,
  });

  final String uid;
  final String username;
  final bool showFollowers;

  @override
  ConsumerState<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends ConsumerState<FollowListScreen> {
  late int _tab = widget.showFollowers ? 0 : 1;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: AppTopBar(
        title: widget.username.isNotEmpty ? '@${widget.username}' : tr('Kết nối', 'Connections'),
        showBack: true,
        bottom: AppSegmentedTabs(
          index: _tab,
          labels: [tr('Người theo dõi', 'Followers'), tr('Đang theo dõi', 'Following')],
          onChanged: (i) => setState(() => _tab = i),
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _List(uid: widget.uid, followers: true),
          _List(uid: widget.uid, followers: false),
        ],
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.uid, required this.followers});
  final String uid;
  final bool followers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(followListProvider((uid: uid, followers: followers)));
    return AsyncValueView<List<AppUser>>(
      value: value,
      onRetry: () =>
          ref.invalidate(followListProvider((uid: uid, followers: followers))),
      builder: (users) {
        if (users.isEmpty) {
          return EmptyView(
            message: followers
                ? tr('Chưa có người theo dõi.', 'No followers yet.')
                : tr('Chưa theo dõi ai.', 'Not following anyone yet.'),
            icon: Icons.people_outline_rounded,
          );
        }
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (_, i) => _UserRow(user: users[i]),
        );
      },
    );
  }
}

class _UserRow extends ConsumerWidget {
  const _UserRow({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authStateProvider).valueOrNull?.uid;
    final isMe = me == user.uid;
    final isFollowing =
        ref.watch(isFollowingProvider(user.uid)).valueOrNull ?? false;

    return AppTile(
      onTap: () => context.push('${Routes.userProfile}/${user.uid}'),
      leading: AppAvatar(
        radius: 22,
        imageProvider: user.photoUrl != null
            ? CachedNetworkImageProvider(user.photoUrl!)
            : null,
      ),
      title: user.username.isNotEmpty ? '@${user.username}' : user.displayName,
      subtitle: user.displayName,
      trailing: isMe
          ? null
          : SizedBox(
              height: 34,
              child: AppButton(
                label: isFollowing
                    ? tr('Đang theo dõi', 'Following')
                    : tr('Theo dõi', 'Follow'),
                variant: isFollowing
                    ? AppButtonVariant.secondary
                    : AppButtonVariant.primary,
                fullWidth: false,
                height: 34,
                onPressed: () {
                  if (me == null) return;
                  final repo = ref.read(followRepositoryProvider);
                  if (isFollowing) {
                    repo.unfollow(currentUid: me, targetUid: user.uid);
                  } else {
                    repo.follow(currentUid: me, targetUid: user.uid);
                  }
                },
              ),
            ),
    );
  }
}
