import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../models/chat.dart';
import '../../../../widgets/components/components.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../providers/message_providers.dart';
import 'voice_bubble.dart';

/// One chat message row: alignment, optional sender label (groups), a reply
/// quote, the typed content, a reactions strip and (for my last message) the
/// read state. Long-press bubbles up to the chat screen's action menu.
class MessageBubble extends ConsumerWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.chat,
    required this.me,
    required this.replyTo,
    required this.showSender,
    required this.isLastMine,
    required this.onLongPress,
    required this.onOpenMedia,
  });

  final Message message;
  final Chat chat;
  final String me;
  final Message? replyTo;
  final bool showSender;
  final bool isLastMine;
  final VoidCallback onLongPress;
  final void Function(String url, bool isVideo) onOpenMedia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = message.senderId == me;
    final align = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 3,
      ),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (showSender && !mine)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm, bottom: 2),
              child: _SenderName(uid: message.senderId),
            ),
          PressScale(
            onLongPress: onLongPress,
            onTap:
                message.type == MessageType.image ||
                    message.type == MessageType.video
                ? () => onOpenMedia(
                    message.mediaUrl!,
                    message.type == MessageType.video,
                  )
                : null,
            child: _bubble(context, ref, mine),
          ),
          if (message.reactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _reactions(),
            ),
          if (isLastMine && !message.deleted)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: AppSpacing.xs),
              child: Text(
                _readLabel(),
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: AppType.caption,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _readLabel() {
    final others = chat.memberIds.where((id) => id != me);
    final seen = others.where((id) => message.readBy.contains(id)).length;
    if (seen == 0) return tr('Đã gửi', 'Sent');
    if (chat.isDm) return tr('Đã xem', 'Seen');
    return tr('Đã xem bởi $seen', 'Seen by $seen');
  }

  Widget _reactions() {
    final counts = <String, int>{};
    for (final e in message.reactions.values) {
      counts[e] = (counts[e] ?? 0) + 1;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.layer1,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.soft,
      ),
      child: Text(
        counts.entries
            .map((e) => e.value > 1 ? '${e.key}${e.value}' : e.key)
            .join(' '),
        style: const TextStyle(fontSize: AppType.label),
      ),
    );
  }

  Widget _bubble(BuildContext context, WidgetRef ref, bool mine) {
    final bg = mine ? null : AppColors.layer2;
    final gradient = mine
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryBright, AppColors.primary],
          )
        : null;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadius.lg),
      topRight: const Radius.circular(AppRadius.lg),
      bottomLeft: Radius.circular(mine ? AppRadius.lg : AppRadius.xxs),
      bottomRight: Radius.circular(mine ? AppRadius.xxs : AppRadius.lg),
    );

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: _padded(message.type)
          ? const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            )
          : const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bg,
        gradient: gradient,
        borderRadius: radius,
        border: mine ? null : Border.all(color: AppColors.borderSubtle),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.pinned && !message.deleted)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.push_pin_rounded,
                    size: AppIconSize.xs,
                    color: mine ? Colors.white70 : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tr('Đã ghim', 'Pinned'),
                    style: TextStyle(
                      fontSize: AppType.caption,
                      color: mine ? Colors.white70 : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          if (replyTo != null) _replyQuote(mine),
          _content(context, ref, mine),
        ],
      ),
    );
  }

  bool _padded(MessageType t) =>
      t == MessageType.text ||
      t == MessageType.voice ||
      t == MessageType.post ||
      t == MessageType.story;

  Widget _replyQuote(bool mine) {
    final r = replyTo!;
    final preview = switch (r.type) {
      MessageType.text => r.text ?? '',
      MessageType.image => '📷 ${tr('Ảnh', 'Photo')}',
      MessageType.video => '🎥 Video',
      MessageType.voice => '🎙️ ${tr('Thoại', 'Voice')}',
      _ => tr('Nội dung', 'Content'),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: (mine ? Colors.white : AppColors.primary).withValues(
          alpha: 0.14,
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border(
          left: BorderSide(
            color: mine ? Colors.white : AppColors.primary,
            width: 3,
          ),
        ),
      ),
      child: Text(
        preview,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: AppType.label,
          color: mine ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, bool mine) {
    final fg = mine ? Colors.white : AppColors.textPrimary;

    if (message.deleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.block_rounded,
            size: AppIconSize.sm,
            color: fg.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Text(
            tr('Tin nhắn đã thu hồi', 'Message unsent'),
            style: TextStyle(
              color: fg.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
              fontSize: AppType.body,
            ),
          ),
        ],
      );
    }

    switch (message.type) {
      case MessageType.text:
        return Text(
          message.text ?? '',
          style: TextStyle(color: fg, fontSize: AppType.subhead, height: 1.3),
        );
      case MessageType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: CachedNetworkImage(
            imageUrl: message.mediaUrl!,
            width: 220,
            fit: BoxFit.cover,
          ),
        );
      case MessageType.video:
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(width: 220, height: 260, color: AppColors.layer3),
              const Icon(
                Icons.play_circle_fill_rounded,
                size: 54,
                color: Colors.white,
              ),
            ],
          ),
        );
      case MessageType.voice:
        return VoiceBubble(
          url: message.mediaUrl!,
          durationMs: message.durationMs,
          mine: mine,
        );
      case MessageType.post:
      case MessageType.story:
        return _sharedCard(ref, mine);
    }
  }

  Widget _sharedCard(WidgetRef ref, bool mine) {
    final async = ref.watch(sharedPostProvider(message.refId ?? ''));
    final fg = mine ? Colors.white : AppColors.textPrimary;
    final post = async.valueOrNull;
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                message.type == MessageType.story
                    ? Icons.auto_stories_rounded
                    : Icons.grid_view_rounded,
                size: AppIconSize.sm,
                color: fg.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Text(
                message.type == MessageType.story
                    ? tr('Story', 'Story')
                    : tr('Bài viết', 'Post'),
                style: TextStyle(
                  color: fg.withValues(alpha: 0.8),
                  fontSize: AppType.label,
                  fontWeight: AppType.medium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (post != null && post.media.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: CachedNetworkImage(
                imageUrl: post.media.first.url,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 200,
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.layer3,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                Icons.image_outlined,
                color: AppColors.textTertiary,
              ),
            ),
          if ((message.text ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                message.text!,
                style: TextStyle(color: fg, fontSize: AppType.body),
              ),
            ),
        ],
      ),
    );
  }
}

class _SenderName extends ConsumerWidget {
  const _SenderName({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider(uid)).valueOrNull;
    final name = user?.username.isNotEmpty == true
        ? user!.username
        : (user?.displayName ?? '');
    return Text(
      name,
      style: TextStyle(
        color: AppColors.primary,
        fontSize: AppType.label,
        fontWeight: AppType.bold,
      ),
    );
  }
}
