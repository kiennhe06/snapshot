import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/chat.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/components/components.dart';
import '../../../widgets/empty_view.dart';
import '../../../widgets/motion/motion.dart';
import '../../../widgets/stickers/sticker_message.dart';
import '../../auth/providers/auth_providers.dart';
import '../../interactions/providers/interaction_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/message_providers.dart';
import 'chat_screen.dart';

/// Pending message requests: conversations started by people who do not follow
/// the user back. Triage each with Accept (moves to the main inbox), Delete, or
/// Block. Tapping a row opens the conversation to read before deciding.
class MessageRequestsScreen extends ConsumerWidget {
  const MessageRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(requestChatsProvider);
    final me = ref.watch(authStateProvider).valueOrNull?.uid ?? '';

    return AppScaffold(
      topBar: AppTopBar(
        title: tr('Tin nhắn chờ', 'Message requests'),
        showBack: true,
      ),
      body: AsyncValueView<List<Chat>>(
        value: requests,
        onRetry: () => ref.invalidate(chatsProvider),
        loading: const ListRowsSkeleton(),
        builder: (list) {
          if (list.isEmpty) {
            return EmptyView(
              message: tr(
                'Không có tin nhắn chờ nào.',
                'No message requests.',
              ),
              icon: Icons.mark_email_read_outlined,
            );
          }
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Text(
                  tr(
                    'Người gửi sẽ không biết bạn đã xem cho đến khi bạn chấp nhận.',
                    'Senders won\'t know you\'ve seen their request until you accept.',
                  ),
                  style: AppText.label.copyWith(color: AppColors.textSecondary),
                ),
              ),
              for (final c in list) _RequestRow(chat: c, me: me),
            ],
          );
        },
      ),
    );
  }
}

class _RequestRow extends ConsumerWidget {
  const _RequestRow({required this.chat, required this.me});
  final Chat chat;
  final String me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final other = ref
        .watch(userProfileProvider(chat.otherMember(me)))
        .valueOrNull;
    final title = other?.username.isNotEmpty == true
        ? other!.username
        : (other?.displayName ?? tr('Người dùng', 'User'));
    final repo = ref.read(chatRepositoryProvider);

    Future<void> block() async {
      final ok = await showAppConfirm(
        context,
        title: tr('Chặn $title?', 'Block $title?'),
        message: tr(
          'Họ sẽ không thể nhắn tin hay tìm thấy bạn. Cuộc trò chuyện sẽ bị xoá.',
          'They won\'t be able to message or find you. This request will be removed.',
        ),
        confirmLabel: tr('Chặn', 'Block'),
        destructive: true,
      );
      if (ok != true) return;
      await ref
          .read(relationRepositoryProvider)
          .setRelation(
            uid: me,
            kind: 'blocked',
            targetUid: chat.otherMember(me),
            on: true,
          );
      await repo.deleteChat(chat.chatId);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PressScale(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.chatId)),
            ),
            child: Row(
              children: [
                AppAvatar(
                  radius: 24,
                  imageProvider: other?.photoUrl != null
                      ? CachedNetworkImageProvider(other!.photoUrl!)
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.h3,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stickerPreviewOr(chat.lastText).isEmpty
                            ? tr('Đã gửi lời mời nhắn tin', 'Sent you a request')
                            : stickerPreviewOr(chat.lastText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: tr('Chấp nhận', 'Accept'),
                  onPressed: () => repo.acceptRequest(chat.chatId),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: tr('Xoá', 'Delete'),
                  variant: AppButtonVariant.secondary,
                  onPressed: () => repo.deleteChat(chat.chatId),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppIconButton(
                icon: Icons.block_rounded,
                tooltip: tr('Chặn', 'Block'),
                onTap: block,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
