import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/motion.dart';
import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../models/ai_message.dart';
import '../../../widgets/components/components.dart';
import '../../auth/providers/auth_providers.dart';
import '../../feed/data/interest_repository.dart';
import '../../feed/providers/feed_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/ai_providers.dart';

/// "Snapshot AI" — a chat with a Gemini-backed assistant that is grounded on
/// what the user taught it (memory) and the topics they engage with, so it
/// feels like it learns and can be taught without ever training the model.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _generating = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: AppMotion.base,
          curve: AppMotion.standard,
        );
      }
    });
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (text.isEmpty || uid == null || _generating) return;
    _input.clear();
    final repo = ref.read(aiRepositoryProvider);

    // Prior turns (before this message) are the context; the new text is sent
    // separately so grounding stays consistent even before the stream syncs.
    final history = ref.read(aiMessagesProvider).valueOrNull ?? const [];
    final memory = ref.read(aiMemoryProvider).valueOrNull ?? const [];
    final interests =
        ref.read(interestProfileProvider).valueOrNull ??
        const InterestProfile();
    final displayName = ref.read(myProfileProvider).valueOrNull?.displayName;

    setState(() => _generating = true);
    await repo.addMessage(uid, AiRole.user, text);
    _scrollToBottom();
    try {
      final reply = await repo.generateReply(
        history: history,
        userText: text,
        memory: memory,
        interests: interests,
        displayName: displayName,
      );
      await repo.addMessage(uid, AiRole.model, reply);
    } catch (_) {
      await repo.addMessage(
        uid,
        AiRole.model,
        tr(
          'Xin lỗi, mình gặp sự cố khi trả lời. Hãy thử lại nhé.',
          'Sorry, I hit an error. Please try again.',
        ),
      );
      if (mounted) {
        showAppToast(
          context,
          tr('Không kết nối được trợ lý AI.', 'Couldn\'t reach the assistant.'),
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
      _scrollToBottom();
    }
  }

  Future<void> _teach(String fact) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await ref.read(aiRepositoryProvider).addMemory(uid, fact);
    if (mounted) {
      showAppToast(
        context,
        tr('Đã dạy cho AI ghi nhớ điều này.', 'Taught the assistant to remember this.'),
        type: AppToastType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(aiMessagesProvider);

    return AppScaffold(
      topBar: AppTopBar(
        showBack: true,
        titleWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _AiAvatar(size: 32),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Snapshot AI', style: AppText.h2),
                Text(
                  _generating
                      ? tr('đang soạn…', 'typing…')
                      : tr('Trợ lý của bạn', 'Your assistant'),
                  style: AppText.caption.copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          AppIconButton(
            icon: Icons.psychology_rounded,
            tooltip: tr('Trí nhớ của AI', 'AI memory'),
            onTap: () => showAppSheet<void>(
              context,
              builder: (_) => const _MemorySheet(),
            ),
          ),
          AppIconButton(
            icon: Icons.delete_sweep_rounded,
            tooltip: tr('Xoá hội thoại', 'Clear chat'),
            onTap: _confirmClear,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Text(tr('Có lỗi xảy ra.', 'Something went wrong.')),
              ),
              data: (list) {
                if (list.isEmpty && !_generating) {
                  return _EmptyState(onPick: _send);
                }
                _scrollToBottom();
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: list.length + (_generating ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i >= list.length) return const _ThinkingBubble();
                    final m = list[i];
                    return _Bubble(
                      message: m,
                      onTeach: m.isUser ? () => _teach(m.text) : null,
                    );
                  },
                );
              },
            ),
          ),
          _Composer(
            controller: _input,
            enabled: !_generating,
            onSend: () => _send(_input.text),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final ok = await showAppConfirm(
      context,
      title: tr('Xoá hội thoại?', 'Clear chat?'),
      message: tr(
        'Toàn bộ tin nhắn sẽ bị xoá. Những điều bạn đã dạy AI vẫn được giữ lại.',
        'All messages will be deleted. What you taught the AI is kept.',
      ),
      confirmLabel: tr('Xoá', 'Clear'),
      destructive: true,
    );
    if (ok == true) {
      await ref.read(aiRepositoryProvider).clearConversation(uid);
    }
  }
}

// ---- Bubbles ----------------------------------------------------------------

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.onTeach});
  final AiMessage message;
  final VoidCallback? onTeach;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bubble = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.78,
      ),
      decoration: BoxDecoration(
        gradient: isUser
            ? LinearGradient(
                colors: [AppColors.primaryBright, AppColors.primary],
              )
            : null,
        color: isUser ? null : AppColors.layer2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: isUser ? null : Border.all(color: AppColors.borderSubtle),
      ),
      child: SelectableText(
        message.text,
        style: TextStyle(
          color: isUser ? Colors.white : AppColors.textPrimary,
          fontSize: AppType.subhead,
          height: 1.35,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const _AiAvatar(size: 28),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: onTeach == null
                  ? null
                  : () => _teachMenu(context),
              child: bubble,
            ),
          ),
        ],
      ),
    );
  }

  void _teachMenu(BuildContext context) {
    showAppSheet<void>(
      context,
      builder: (sheetCtx) => AppSheetSurface(
        child: PressScale(
          onTap: () {
            Navigator.pop(sheetCtx);
            onTeach?.call();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(Icons.psychology_rounded, color: AppColors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    tr(
                      'Dạy AI ghi nhớ điều này',
                      'Teach the AI to remember this',
                    ),
                    style: AppText.h3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An animated "thinking" row shown while the assistant generates a reply.
class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const _AiAvatar(size: 28),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.layer2,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: const _Dots(),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatefulWidget {
  const _Dots();
  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = (_c.value + i / 3) % 1.0;
          final opacity = 0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: opacity),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---- Empty state / suggestions ---------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final prompts = <(String, String)>[
      (
        '✍️',
        tr('Viết caption cho ảnh mới của tôi', 'Write a caption for my new photo'),
      ),
      ('#️⃣', tr('Gợi ý 10 hashtag đang hot', 'Suggest 10 trending hashtags')),
      ('💡', tr('Cho tôi ý tưởng nội dung hôm nay', 'Give me content ideas for today')),
      ('🙋', tr('Viết bio hồ sơ thật chất', 'Write a catchy profile bio')),
    ];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.xl),
        const Center(child: _AiAvatar(size: 72)),
        const SizedBox(height: AppSpacing.lg),
        Text(
          tr('Chào bạn! Mình là Snapshot AI', 'Hi! I\'m Snapshot AI'),
          textAlign: TextAlign.center,
          style: AppText.h1,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          tr(
            'Mình giúp bạn viết caption, hashtag, bio và lên ý tưởng nội dung. '
            'Càng dùng, mình càng hiểu bạn — và bạn dạy mình ghi nhớ được.',
            'I help with captions, hashtags, bios and content ideas. The more '
            'you use me, the better I know you — and you can teach me to remember.',
          ),
          textAlign: TextAlign.center,
          style: AppText.label.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final (emoji, prompt) in prompts)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PressScale(
              onTap: () => onPick(prompt),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.layer2,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: Text(prompt, style: AppText.body)),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: AppIconSize.sm,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---- Composer ---------------------------------------------------------------

class _Composer extends StatefulWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      color: AppColors.layer1,
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.layer3,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: TextField(
                  controller: widget.controller,
                  enabled: widget.enabled,
                  minLines: 1,
                  maxLines: 5,
                  cursorColor: AppColors.primary,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppType.subhead,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: tr('Hỏi Snapshot AI…', 'Ask Snapshot AI…'),
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap:
                  widget.enabled && widget.controller.text.trim().isNotEmpty
                  ? widget.onSend
                  : null,
              child: Opacity(
                opacity:
                    widget.enabled &&
                        widget.controller.text.trim().isNotEmpty
                    ? 1
                    : 0.4,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primaryBright, AppColors.primary],
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: AppIconSize.md,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Memory sheet -----------------------------------------------------------

class _MemorySheet extends ConsumerStatefulWidget {
  const _MemorySheet();
  @override
  ConsumerState<_MemorySheet> createState() => _MemorySheetState();
}

class _MemorySheetState extends ConsumerState<_MemorySheet> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    final memory = ref.watch(aiMemoryProvider).valueOrNull ?? const [];
    final repo = ref.read(aiRepositoryProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: AppSheetSurface(
        title: tr('Trí nhớ của AI', 'AI memory'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(
                'Những điều này được nạp vào mỗi câu trả lời để AI hiểu bạn hơn.',
                'These are fed into every reply so the AI understands you better.',
              ),
              style: AppText.label.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            if (memory.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  tr(
                    'Chưa có gì. Thêm điều bạn muốn AI luôn nhớ (ví dụ: "Tôi thích caption ngắn, hài hước").',
                    'Nothing yet. Add something you want the AI to always remember.',
                  ),
                  style: TextStyle(color: AppColors.textTertiary),
                ),
              )
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final fact in memory)
                    Chip(
                      label: Text(fact),
                      backgroundColor: AppColors.layer2,
                      side: BorderSide(color: AppColors.borderSubtle),
                      deleteIcon: const Icon(Icons.close_rounded, size: 16),
                      onDeleted: uid == null
                          ? null
                          : () => repo.removeMemory(uid, fact),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _field,
              label: tr('Dạy điều mới', 'Teach something new'),
              hint: tr('Ví dụ: Tôi là nhiếp ảnh gia đường phố', 'e.g. I\'m a street photographer'),
              icon: Icons.add_rounded,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: tr('Thêm vào trí nhớ', 'Add to memory'),
                    onPressed:
                        uid == null || _field.text.trim().isEmpty
                        ? null
                        : () async {
                            await repo.addMemory(uid, _field.text);
                            _field.clear();
                            setState(() {});
                          },
                  ),
                ),
                if (memory.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.sm),
                  AppIconButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: tr('Xoá toàn bộ', 'Clear all'),
                    onTap: uid == null ? null : () => repo.clearMemory(uid),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Shared AI avatar -------------------------------------------------------

class _AiAvatar extends StatelessWidget {
  const _AiAvatar({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: size * 0.52,
      ),
    );
  }
}
