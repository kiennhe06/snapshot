import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/chat.dart';
import '../../../widgets/components/components.dart';
import '../../auth/providers/auth_providers.dart';
import '../../interactions/providers/interaction_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/message_providers.dart';

/// Everything you can do with a conversation, in one place: view the person /
/// members, mute, archive, block (DM) or manage members and leave (group).
class ConversationDetailScreen extends ConsumerWidget {
  const ConversationDetailScreen({super.key, required this.chatId});
  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatProvider(chatId)).valueOrNull;
    final me = ref.watch(authStateProvider).valueOrNull?.uid ?? '';

    return AppScaffold(
      topBar: AppTopBar(
        title: tr('Chi tiết', 'Details'),
        showBack: true,
      ),
      body: chat == null
          ? const Center(child: CircularProgressIndicator())
          : (chat.isDm
                ? _DmDetail(chat: chat, me: me)
                : _GroupDetail(chat: chat, me: me)),
    );
  }
}

// ---- DM ---------------------------------------------------------------------

class _DmDetail extends ConsumerWidget {
  const _DmDetail({required this.chat, required this.me});
  final Chat chat;
  final String me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherUid = chat.otherMember(me);
    final other = ref.watch(userProfileProvider(otherUid)).valueOrNull;
    final muted = chat.isMutedBy(me);
    final archived = chat.isArchivedBy(me);
    final blocked = (ref.watch(blockedIdsProvider).valueOrNull ?? const [])
        .contains(otherUid);
    final repo = ref.read(chatRepositoryProvider);
    final relations = ref.read(relationRepositoryProvider);

    return ListView(
      children: [
        _ProfileCard(
          photoUrl: other?.photoUrl,
          title: other?.username.isNotEmpty == true
              ? other!.username
              : (other?.displayName ?? tr('Người dùng', 'User')),
          subtitle: other?.displayName,
          verified: other?.isVerified ?? false,
          onTap: () => context.push('${Routes.userProfile}/$otherUid'),
        ),
        const Divider(height: 1),
        _ToggleRow(
          icon: Icons.notifications_off_rounded,
          label: tr('Tắt thông báo', 'Mute'),
          value: muted,
          onChanged: (v) => repo.setMuted(chat.chatId, me, v),
        ),
        _ToggleRow(
          icon: Icons.archive_rounded,
          label: tr('Lưu trữ cuộc trò chuyện', 'Archive conversation'),
          value: archived,
          onChanged: (v) => repo.setArchived(chat.chatId, me, v),
        ),
        const Divider(height: 1),
        _ActionRow(
          icon: blocked ? Icons.lock_open_rounded : Icons.block_rounded,
          label: blocked ? tr('Bỏ chặn', 'Unblock') : tr('Chặn', 'Block'),
          destructive: !blocked,
          onTap: () async {
            if (blocked) {
              await relations.setRelation(
                uid: me,
                kind: 'blocked',
                targetUid: otherUid,
                on: false,
              );
              return;
            }
            final ok = await showAppConfirm(
              context,
              title: tr('Chặn người này?', 'Block this person?'),
              message: tr(
                'Họ sẽ không thể nhắn tin hay tìm thấy bạn.',
                'They won\'t be able to message or find you.',
              ),
              confirmLabel: tr('Chặn', 'Block'),
              destructive: true,
            );
            if (ok == true) {
              await relations.setRelation(
                uid: me,
                kind: 'blocked',
                targetUid: otherUid,
                on: true,
              );
            }
          },
        ),
        _ActionRow(
          icon: Icons.delete_outline_rounded,
          label: tr('Xoá cuộc trò chuyện', 'Delete conversation'),
          destructive: true,
          onTap: () async {
            final ok = await showAppConfirm(
              context,
              title: tr('Xoá cuộc trò chuyện?', 'Delete conversation?'),
              message: tr(
                'Cuộc trò chuyện sẽ bị xoá khỏi hộp thư của bạn.',
                'This conversation will be removed from your inbox.',
              ),
              confirmLabel: tr('Xoá', 'Delete'),
              destructive: true,
            );
            if (ok == true && context.mounted) {
              await repo.deleteChat(chat.chatId);
              if (context.mounted) {
                // Pop detail + chat back to inbox.
                Navigator.of(context)
                  ..pop()
                  ..pop();
              }
            }
          },
        ),
      ],
    );
  }
}

// ---- Group ------------------------------------------------------------------

class _GroupDetail extends ConsumerWidget {
  const _GroupDetail({required this.chat, required this.me});
  final Chat chat;
  final String me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = chat.isMutedBy(me);
    final isAdmin = chat.adminIds.contains(me);
    final repo = ref.read(chatRepositoryProvider);

    return ListView(
      children: [
        _ProfileCard(
          photoUrl: chat.photoUrl,
          title: chat.name ?? tr('Nhóm', 'Group'),
          subtitle: tr(
            '${chat.memberIds.length} thành viên',
            '${chat.memberIds.length} members',
          ),
          fallbackIcon: Icons.group_rounded,
        ),
        const Divider(height: 1),
        _ToggleRow(
          icon: Icons.notifications_off_rounded,
          label: tr('Tắt thông báo', 'Mute'),
          value: muted,
          onChanged: (v) => repo.setMuted(chat.chatId, me, v),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(child: AppSectionLabel(tr('Thành viên', 'Members'))),
              if (isAdmin)
                PressScale(
                  onTap: () => _addMembers(context, ref),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_add_alt_1_rounded,
                        size: AppIconSize.sm,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tr('Thêm', 'Add'),
                        style: AppText.label.copyWith(
                          color: AppColors.primary,
                          fontWeight: AppType.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        for (final uid in chat.memberIds)
          _MemberRow(
            uid: uid,
            isAdmin: chat.adminIds.contains(uid),
            canRemove: isAdmin && uid != me,
            onRemove: () => repo.removeMember(chat.chatId, uid),
          ),
        const Divider(height: 1),
        _ActionRow(
          icon: Icons.logout_rounded,
          label: tr('Rời nhóm', 'Leave group'),
          destructive: true,
          onTap: () async {
            final ok = await showAppConfirm(
              context,
              title: tr('Rời nhóm?', 'Leave group?'),
              message: tr(
                'Bạn sẽ không nhận tin nhắn từ nhóm này nữa.',
                'You will stop receiving messages from this group.',
              ),
              confirmLabel: tr('Rời nhóm', 'Leave'),
              destructive: true,
            );
            if (ok == true && context.mounted) {
              await repo.removeMember(chat.chatId, me);
              if (context.mounted) {
                Navigator.of(context)
                  ..pop()
                  ..pop();
              }
            }
          },
        ),
      ],
    );
  }

  /// Admin: add mutual-friends who are not already in the group.
  Future<void> _addMembers(BuildContext context, WidgetRef ref) async {
    final friends = ref.read(mutualFriendsProvider).valueOrNull ?? const [];
    final candidates = friends
        .where((u) => !chat.memberIds.contains(u.uid))
        .toList();
    if (candidates.isEmpty) {
      showAppToast(
        context,
        tr(
          'Không còn bạn bè nào để thêm.',
          'No more friends to add.',
        ),
      );
      return;
    }
    final picked = <String>{};
    await showAppSheet<void>(
      context,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => AppSheetSurface(
          title: tr('Thêm thành viên', 'Add members'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final u in candidates)
                      AppTile(
                        onTap: () => setSheet(() {
                          picked.contains(u.uid)
                              ? picked.remove(u.uid)
                              : picked.add(u.uid);
                        }),
                        leading: AppAvatar(
                          radius: 20,
                          imageProvider: u.photoUrl != null
                              ? CachedNetworkImageProvider(u.photoUrl!)
                              : null,
                        ),
                        title: u.username.isNotEmpty
                            ? u.username
                            : u.displayName,
                        trailing: Icon(
                          picked.contains(u.uid)
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: picked.contains(u.uid)
                              ? AppColors.primary
                              : AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: tr('Thêm (${picked.length})', 'Add (${picked.length})'),
                onPressed: picked.isEmpty
                    ? null
                    : () async {
                        await ref
                            .read(chatRepositoryProvider)
                            .addMembers(chat.chatId, picked.toList());
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberRow extends ConsumerWidget {
  const _MemberRow({
    required this.uid,
    required this.isAdmin,
    required this.canRemove,
    required this.onRemove,
  });
  final String uid;
  final bool isAdmin;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(userProfileProvider(uid)).valueOrNull;
    return AppTile(
      onTap: () => context.push('${Routes.userProfile}/$uid'),
      leading: AppAvatar(
        radius: 20,
        imageProvider: u?.photoUrl != null
            ? CachedNetworkImageProvider(u!.photoUrl!)
            : null,
      ),
      title: u?.username.isNotEmpty == true
          ? u!.username
          : (u?.displayName ?? tr('Người dùng', 'User')),
      subtitle: isAdmin ? tr('Quản trị viên', 'Admin') : null,
      trailing: canRemove
          ? AppIconButton(
              icon: Icons.remove_circle_outline_rounded,
              tooltip: tr('Xoá khỏi nhóm', 'Remove'),
              onTap: onRemove,
            )
          : null,
    );
  }
}

// ---- Shared pieces ----------------------------------------------------------

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.title,
    this.subtitle,
    this.photoUrl,
    this.verified = false,
    this.fallbackIcon = Icons.person_rounded,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? photoUrl;
  final bool verified;
  final IconData fallbackIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            AppAvatar(
              radius: 40,
              icon: fallbackIcon,
              imageProvider: photoUrl != null
                  ? CachedNetworkImageProvider(photoUrl!)
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.h2,
                  ),
                ),
                if (verified) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.verified_rounded,
                    size: AppIconSize.sm,
                    color: AppColors.accent,
                  ),
                ],
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: AppText.label.copyWith(color: AppColors.textSecondary),
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                tr('Xem trang cá nhân', 'View profile'),
                style: AppText.label.copyWith(
                  color: AppColors.primary,
                  fontWeight: AppType.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: label,
      trailing: Switch.adaptive(
        value: value,
        activeThumbColor: AppColors.primary,
        onChanged: onChanged,
      ),
      onTap: () => onChanged(!value),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.danger : AppColors.textPrimary;
    return AppTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: destructive ? AppColors.danger : AppColors.textSecondary,
      ),
      title: label,
      titleColor: color,
    );
  }
}
