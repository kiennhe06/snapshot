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

/// Compact, conversational time label ("just now", "3h", then a date).
String _relTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 45) return tr('vừa xong', 'just now');
  if (d.inMinutes < 60) return tr('${d.inMinutes} phút', '${d.inMinutes}m');
  if (d.inHours < 24) return tr('${d.inHours} giờ', '${d.inHours}h');
  if (d.inDays < 7) return tr('${d.inDays} ngày', '${d.inDays}d');
  return DateFormat('dd/MM').format(t);
}

/// Full comments experience: a post-context header, a threaded conversation
/// with a connector rail, animated likes, and an avatar composer.
class CommentsScreen extends ConsumerStatefulWidget {
  const CommentsScreen({super.key, required this.post});

  final Post post;

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _expanded = <String>{};
  Comment? _replyingTo;
  bool _sending = false;
  bool _hasText = false;
  bool _sortByLikes = false; // false = newest, true = most liked

  String get _postId => widget.post.postId;
  bool get _iAmPostAuthor {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    return uid == widget.post.authorId;
  }

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      final has = _input.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
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

  void _startReply(Comment c) {
    setState(() => _replyingTo = c);
    _focus.requestFocus();
  }

  void _insertEmoji(String e) {
    final sel = _input.selection;
    final text = _input.text;
    final start = sel.start < 0 ? text.length : sel.start;
    final end = sel.end < 0 ? text.length : sel.end;
    final newText = text.substring(0, start) + e + text.substring(end);
    _input.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + e.length),
    );
    _focus.requestFocus();
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
          _ContextHeader(post: widget.post, commentsAsync: commentsAsync),
          _SortBar(
            byLikes: _sortByLikes,
            onChanged: (v) => setState(() => _sortByLikes = v),
          ),
          Expanded(
            child: AsyncValueView<List<Comment>>(
              value: commentsAsync,
              onRetry: () => ref.invalidate(commentsProvider(_postId)),
              builder: (all) {
                final visible = all.where((c) => !_hidden(c, hiddenWords));
                final roots = visible.where((c) => !c.isReply).toList()
                  ..sort((a, b) {
                    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
                    if (_sortByLikes && a.likesCount != b.likesCount) {
                      return b.likesCount.compareTo(a.likesCount);
                    }
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
                      'Chưa có bình luận nào.\nHãy bắt đầu cuộc trò chuyện!',
                      'No comments yet.\nStart the conversation!',
                    ),
                    icon: Icons.mode_comment_outlined,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.sm,
                    bottom: AppSpacing.lg,
                  ),
                  itemCount: roots.length,
                  itemBuilder: (_, i) {
                    final root = roots[i];
                    final replies =
                        repliesByParent[root.commentId] ?? const [];
                    final showReplies = _expanded.contains(root.commentId);
                    return _Thread(
                      root: root,
                      replies: replies,
                      postAuthorId: widget.post.authorId,
                      showReplies: showReplies,
                      onToggleReplies: () => setState(() {
                        showReplies
                            ? _expanded.remove(root.commentId)
                            : _expanded.add(root.commentId);
                      }),
                      onReply: _startReply,
                      onMenu: _menu,
                    );
                  },
                );
              },
            ),
          ),
          _Composer(
            input: _input,
            focus: _focus,
            hasText: _hasText,
            sending: _sending,
            replyingTo: _replyingTo,
            onSend: _send,
            onEmoji: _insertEmoji,
            onCancelReply: () => setState(() => _replyingTo = null),
          ),
        ],
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

/// Slim context strip: the post thumbnail + caption + a live comment count, so
/// the screen opens with content instead of an empty header.
class _ContextHeader extends ConsumerWidget {
  const _ContextHeader({required this.post, required this.commentsAsync});
  final Post post;
  final AsyncValue<List<Comment>> commentsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = commentsAsync.valueOrNull?.length ?? post.commentsCount;
    final author = ref.watch(userProfileProvider(post.authorId)).valueOrNull;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: post.coverUrl.isEmpty
                ? Container(
                    width: 40,
                    height: 40,
                    color: AppColors.layer3,
                    child: Icon(
                      Icons.image_outlined,
                      size: AppIconSize.md,
                      color: AppColors.textTertiary,
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: post.coverUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        author != null && author.username.isNotEmpty
                            ? '@${author.username}'
                            : (count > 0
                                  ? tr('$count bình luận', '$count comments')
                                  : tr('Bình luận', 'Comments')),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppType.subhead,
                          fontWeight: AppType.bold,
                        ),
                      ),
                    ),
                    if (author?.isVerified == true) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.verified_rounded,
                        size: AppIconSize.sm,
                        color: AppColors.accent,
                      ),
                    ],
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      count > 0 ? '· $count' : '',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: AppType.label,
                        fontWeight: AppType.medium,
                      ),
                    ),
                  ],
                ),
                if (post.caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      post.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: AppType.label,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sort control: newest first or most liked first.
class _SortBar extends StatelessWidget {
  const _SortBar({required this.byLikes, required this.onChanged});
  final bool byLikes;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool active, VoidCallback onTap) => PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.14)
              : AppColors.layer3,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.primary : AppColors.textSecondary,
            fontSize: AppType.label,
            fontWeight: AppType.bold,
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(
            Icons.sort_rounded,
            size: AppIconSize.sm,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.sm),
          chip(tr('Mới nhất', 'Newest'), !byLikes, () => onChanged(false)),
          const SizedBox(width: AppSpacing.sm),
          chip(tr('Nhiều tim nhất', 'Top'), byLikes, () => onChanged(true)),
        ],
      ),
    );
  }
}

/// A root comment plus its reply rail.
class _Thread extends StatelessWidget {
  const _Thread({
    required this.root,
    required this.replies,
    required this.postAuthorId,
    required this.showReplies,
    required this.onToggleReplies,
    required this.onReply,
    required this.onMenu,
  });

  final Comment root;
  final List<Comment> replies;
  final String postAuthorId;
  final bool showReplies;
  final VoidCallback onToggleReplies;
  final void Function(Comment) onReply;
  final void Function(Comment) onMenu;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentRow(
          comment: root,
          isAuthor: root.authorId == postAuthorId,
          onReply: () => onReply(root),
          onMenu: () => onMenu(root),
        ),
        if (root.replyCount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 58, bottom: AppSpacing.xs),
            child: PressScale(
              onTap: onToggleReplies,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 22, height: 1, color: AppColors.borderStrong),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    showReplies
                        ? tr('Ẩn trả lời', 'Hide replies')
                        : tr(
                            'Xem ${root.replyCount} trả lời',
                            'View ${root.replyCount} replies',
                          ),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppType.label,
                      fontWeight: AppType.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (showReplies && replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.borderSubtle, width: 1.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in replies)
                    _CommentRow(
                      comment: r,
                      compact: true,
                      isAuthor: r.authorId == postAuthorId,
                      onReply: () => onReply(r),
                      onMenu: () => onMenu(r),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CommentRow extends ConsumerWidget {
  const _CommentRow({
    required this.comment,
    required this.onReply,
    required this.onMenu,
    this.compact = false,
    this.isAuthor = false,
  });

  final Comment comment;
  final VoidCallback onReply;
  final VoidCallback onMenu;
  final bool compact;
  final bool isAuthor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = ref.watch(userProfileProvider(comment.authorId)).valueOrNull;
    final name = author?.username.isNotEmpty == true
        ? author!.username
        : (author?.displayName ?? '...');
    final avatarRadius = compact ? 14.0 : 18.0;

    final row = Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? AppSpacing.md : AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(
            radius: avatarRadius,
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
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: compact ? AppType.small : AppType.body,
                          fontWeight: AppType.bold,
                        ),
                      ),
                    ),
                    if (isAuthor) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppRadius.xxs),
                        ),
                        child: Text(
                          tr('TÁC GIẢ', 'AUTHOR'),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: AppType.caption,
                            fontWeight: AppType.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _relTime(comment.createdAt),
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: AppType.small,
                      ),
                    ),
                    if (comment.pinned) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        Icons.push_pin,
                        size: AppIconSize.xs,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  comment.text,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppType.subhead,
                    height: 1.32,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                PressScale(
                  onTap: onReply,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      tr('Trả lời', 'Reply'),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppType.small,
                        fontWeight: AppType.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _LikeButton(comment: comment),
        ],
      ),
    );

    return PressScale(onLongPress: onMenu, scale: 0.99, child: row);
  }
}

/// Heart + count with a little bounce when you tap it.
class _LikeButton extends ConsumerStatefulWidget {
  const _LikeButton({required this.comment});
  final Comment comment;

  @override
  ConsumerState<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends ConsumerState<_LikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.35), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.35, end: 1), weight: 60),
  ]).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap(bool liked) {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    if (!liked) _c.forward(from: 0);
    ref
        .read(commentRepositoryProvider)
        .toggleLike(
          postId: widget.comment.postId,
          commentId: widget.comment.commentId,
          uid: uid,
        );
  }

  @override
  Widget build(BuildContext context) {
    final liked =
        ref
            .watch(
              isCommentLikedProvider((
                postId: widget.comment.postId,
                commentId: widget.comment.commentId,
              )),
            )
            .valueOrNull ??
        false;
    return PressScale(
      onTap: () => _tap(liked),
      child: Padding(
        padding: const EdgeInsets.only(top: 1, left: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Icon(
                liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: AppIconSize.md,
                color: liked ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
            SizedBox(
              height: 14,
              child: widget.comment.likesCount > 0
                  ? Text(
                      '${widget.comment.likesCount}',
                      style: TextStyle(
                        color: liked
                            ? AppColors.primary
                            : AppColors.textTertiary,
                        fontSize: AppType.caption,
                        fontWeight: AppType.bold,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Modern conversation composer: your avatar, a soft pill field, a replying-to
/// chip, and a dynamic send button that grows in when there is text.
class _Composer extends ConsumerWidget {
  const _Composer({
    required this.input,
    required this.focus,
    required this.hasText,
    required this.sending,
    required this.replyingTo,
    required this.onSend,
    required this.onEmoji,
    required this.onCancelReply,
  });

  final TextEditingController input;
  final FocusNode focus;
  final bool hasText;
  final bool sending;
  final Comment? replyingTo;
  final VoidCallback onSend;
  final void Function(String) onEmoji;
  final VoidCallback onCancelReply;

  static const _emojis = ['❤️', '🔥', '☕', '😍', '👏', '✨', '🙌'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myProfileProvider).valueOrNull;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
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
            // Quick-emoji strip
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final e in _emojis)
                    PressScale(
                      onTap: () => onEmoji(e),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                ],
              ),
            ),
            if (replyingTo != null)
              _ReplyingChip(comment: replyingTo!, onCancel: onCancelReply),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppAvatar(
                  radius: 16,
                  imageProvider: me?.photoUrl != null
                      ? CachedNetworkImageProvider(me!.photoUrl!)
                      : null,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: AppColors.layer3,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: TextField(
                      controller: input,
                      focusNode: focus,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      cursorColor: AppColors.primary,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: AppType.subhead,
                      ),
                      decoration: InputDecoration(
                        hintText: replyingTo != null
                            ? tr('Viết trả lời...', 'Write a reply...')
                            : tr('Thêm bình luận...', 'Add a comment...'),
                        hintStyle: TextStyle(
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
                _SendButton(
                  visible: hasText || sending,
                  sending: sending,
                  onTap: onSend,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.visible,
    required this.sending,
    required this.onTap,
  });
  final bool visible;
  final bool sending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: visible ? 1 : 0.6,
      duration: AppMotion.fast,
      curve: AppMotion.emphasized,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0.4,
        duration: AppMotion.fast,
        child: PressScale(
          onTap: (visible && !sending) ? onTap : null,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: visible
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryBright, AppColors.primary],
                    )
                  : null,
              color: visible ? null : AppColors.layer3,
              boxShadow: visible ? AppShadows.brandGlow : null,
            ),
            child: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    Icons.arrow_upward_rounded,
                    size: AppIconSize.md,
                    color: visible ? Colors.white : AppColors.textTertiary,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ReplyingChip extends ConsumerWidget {
  const _ReplyingChip({required this.comment, required this.onCancel});
  final Comment comment;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = ref.watch(userProfileProvider(comment.authorId)).valueOrNull;
    final name = author?.username.isNotEmpty == true
        ? author!.username
        : (author?.displayName ?? '...');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.layer3,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(
              Icons.reply_rounded,
              size: AppIconSize.sm,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                tr('Đang trả lời $name', 'Replying to $name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppType.label,
                  fontWeight: AppType.medium,
                ),
              ),
            ),
            PressScale(
              onTap: onCancel,
              child: Icon(
                Icons.close_rounded,
                size: AppIconSize.sm,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
