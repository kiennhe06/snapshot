import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/comment.dart';
import '../../../models/post.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/components/components.dart';
import '../../../widgets/empty_view.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/interaction_providers.dart';

/// Full comments experience: list roots + replies, like, reply, pin, delete,
/// report, and hidden-word filtering.
class CommentsScreen extends ConsumerStatefulWidget {
  const CommentsScreen({super.key, required this.post});

  final Post post;

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> {
  final _input = TextEditingController();
  final _expanded = <String>{};
  Comment? _replyingTo;
  bool _sending = false;

  String get _postId => widget.post.postId;
  bool get _iAmPostAuthor {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    return uid == widget.post.authorId;
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    final text = _input.text.trim();
    if (uid == null || text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(commentRepositoryProvider)
          .addComment(
            postId: _postId,
            uid: uid,
            text: text,
            parentId: _replyingTo?.parentId ?? _replyingTo?.commentId,
          );
      _input.clear();
      setState(() => _replyingTo = null);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _hidden(Comment c, List<String> words) {
    final lower = c.text.toLowerCase();
    return words.any(
      (w) => w.trim().isNotEmpty && lower.contains(w.toLowerCase()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(_postId));
    final hiddenWords = ref.watch(hiddenWordsProvider).valueOrNull ?? const [];

    return AppScaffold(
      topBar: AppTopBar(title: tr('Bình luận', 'Comments'), showBack: true),
      body: Column(
        children: [
          Expanded(
            child: AsyncValueView<List<Comment>>(
              value: commentsAsync,
              onRetry: () => ref.invalidate(commentsProvider(_postId)),
              builder: (all) {
                final visible = all.where((c) => !_hidden(c, hiddenWords));
                final roots = visible.where((c) => !c.isReply).toList()
                  ..sort((a, b) {
                    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
                    return b.createdAt.compareTo(a.createdAt);
                  });
                final repliesByParent = <String, List<Comment>>{};
                for (final c in visible.where((c) => c.isReply)) {
                  repliesByParent.putIfAbsent(c.parentId!, () => []).add(c);
                }
                for (final list in repliesByParent.values) {
                  list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                }

                if (roots.isEmpty) {
                  return EmptyView(
                    message: tr(
                      'Chưa có bình luận nào.\nHãy là người đầu tiên!',
                      'No comments yet.\nBe the first!',
                    ),
                    icon: Icons.mode_comment_outlined,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  itemCount: roots.length,
                  itemBuilder: (_, i) {
                    final root = roots[i];
                    final replies = repliesByParent[root.commentId] ?? const [];
                    final showReplies = _expanded.contains(root.commentId);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CommentRow(
                          comment: root,
                          onReply: () => setState(() => _replyingTo = root),
                          onMenu: () => _menu(root),
                        ),
                        if (root.replyCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 64, bottom: 4),
                            child: PressScale(
                              onTap: () => setState(() {
                                if (showReplies) {
                                  _expanded.remove(root.commentId);
                                } else {
                                  _expanded.add(root.commentId);
                                }
                              }),
                              child: Text(
                                showReplies
                                    ? tr('Ẩn trả lời', 'Hide replies')
                                    : tr(
                                        'Xem ${root.replyCount} trả lời',
                                        'View ${root.replyCount} replies',
                                      ),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: AppType.label,
                                  fontWeight: AppType.medium,
                                ),
                              ),
                            ),
                          ),
                        if (showReplies)
                          ...replies.map(
                            (r) => Padding(
                              padding: const EdgeInsets.only(left: 40),
                              child: _CommentRow(
                                comment: r,
                                onReply: () => setState(() => _replyingTo = r),
                                onMenu: () => _menu(r),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.layer1,
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingTo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(child: _ReplyingBanner(comment: _replyingTo!)),
                    PressScale(
                      onTap: () => setState(() => _replyingTo = null),
                      child: const Icon(
                        Icons.close_rounded,
                        size: AppIconSize.sm,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.layer3,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      cursorColor: AppColors.primary,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: AppType.subhead,
                      ),
                      decoration: InputDecoration(
                        hintText: tr('Thêm bình luận...', 'Add a comment...'),
                        hintStyle: const TextStyle(
                          color: AppColors.textTertiary,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppIconButton(
                  icon: Icons.send_rounded,
                  active: true,
                  onTap: _sending ? null : _send,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _menu(Comment c) {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    final isMine = uid == c.authorId;
    showAppMenu(context, [
      if (_iAmPostAuthor && !c.isReply)
        AppMenuAction(
          icon: c.pinned ? Icons.push_pin : Icons.push_pin_outlined,
          label: c.pinned
              ? tr('Bỏ ghim', 'Unpin')
              : tr('Ghim bình luận', 'Pin comment'),
          onTap: () => ref
              .read(commentRepositoryProvider)
              .setPinned(
                postId: _postId,
                commentId: c.commentId,
                pinned: !c.pinned,
              ),
        ),
      if (isMine || _iAmPostAuthor)
        AppMenuAction(
          icon: Icons.delete_outline_rounded,
          label: tr('Xoá bình luận', 'Delete comment'),
          destructive: true,
          onTap: () => ref
              .read(commentRepositoryProvider)
              .deleteComment(postId: _postId, comment: c),
        ),
      if (!isMine)
        AppMenuAction(
          icon: Icons.flag_outlined,
          label: tr('Báo cáo bình luận', 'Report comment'),
          onTap: () {
            if (uid != null) {
              ref
                  .read(relationRepositoryProvider)
                  .report(
                    reporterId: uid,
                    targetType: 'comment',
                    targetId: c.commentId,
                    reason: 'reported from comments',
                  );
            }
            showAppToast(
              context,
              tr('Đã gửi báo cáo.', 'Report sent.'),
              type: AppToastType.success,
            );
          },
        ),
    ]);
  }
}

class _ReplyingBanner extends ConsumerWidget {
  const _ReplyingBanner({required this.comment});
  final Comment comment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = ref.watch(userProfileProvider(comment.authorId)).valueOrNull;
    return Text(
      tr(
        'Đang trả lời ${author?.username ?? '...'}',
        'Replying to ${author?.username ?? '...'}',
      ),
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: AppType.label,
      ),
    );
  }
}

class _CommentRow extends ConsumerWidget {
  const _CommentRow({
    required this.comment,
    required this.onReply,
    required this.onMenu,
  });

  final Comment comment;
  final VoidCallback onReply;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = ref.watch(userProfileProvider(comment.authorId)).valueOrNull;
    final liked =
        ref
            .watch(
              isCommentLikedProvider((
                postId: comment.postId,
                commentId: comment.commentId,
              )),
            )
            .valueOrNull ??
        false;

    return PressScale(
      onLongPress: onMenu,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAvatar(
              radius: 18,
              imageProvider: author?.photoUrl != null
                  ? CachedNetworkImageProvider(author!.photoUrl!)
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        author?.username.isNotEmpty == true
                            ? author!.username
                            : (author?.displayName ?? '...'),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppType.body,
                          fontWeight: AppType.bold,
                        ),
                      ),
                      if (comment.pinned) ...[
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(
                          Icons.push_pin,
                          size: AppIconSize.xs,
                          color: AppColors.primary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    comment.text,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppType.subhead,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Text(
                        DateFormat('dd/MM HH:mm').format(comment.createdAt),
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: AppType.small,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      if (comment.likesCount > 0)
                        Text(
                          tr(
                            '${comment.likesCount} thích',
                            '${comment.likesCount} likes',
                          ),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: AppType.small,
                            fontWeight: AppType.medium,
                          ),
                        ),
                      const SizedBox(width: AppSpacing.lg),
                      PressScale(
                        onTap: onReply,
                        child: Text(
                          tr('Trả lời', 'Reply'),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: AppType.small,
                            fontWeight: AppType.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PressScale(
              onTap: () {
                final uid = ref.read(authStateProvider).valueOrNull?.uid;
                if (uid != null) {
                  ref
                      .read(commentRepositoryProvider)
                      .toggleLike(
                        postId: comment.postId,
                        commentId: comment.commentId,
                        uid: uid,
                      );
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm, top: 2),
                child: Icon(
                  liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: AppIconSize.md,
                  color: liked ? AppColors.primary : AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
