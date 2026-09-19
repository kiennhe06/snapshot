import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../models/story.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/story_providers.dart';

/// Renders one story sticker. [interactive] enables voting/answering (in the
/// viewer); otherwise it is a static preview (composer).
class StoryStickerView extends ConsumerWidget {
  const StoryStickerView({
    super.key,
    required this.storyId,
    required this.sticker,
    this.interactive = false,
    this.onQuestionTap,
  });

  final String storyId;
  final StorySticker sticker;
  final bool interactive;
  final void Function(StorySticker sticker)? onQuestionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (sticker.type) {
      case StickerType.poll:
        return _PollSticker(
          storyId: storyId,
          sticker: sticker,
          interactive: interactive,
        );
      case StickerType.slider:
        return _SliderSticker(
          storyId: storyId,
          sticker: sticker,
          interactive: interactive,
        );
      case StickerType.quiz:
        return _QuizSticker(sticker: sticker, interactive: interactive);
      case StickerType.countdown:
        return _CountdownSticker(sticker: sticker);
      case StickerType.question:
        return _QuestionSticker(
          sticker: sticker,
          onTap: interactive ? () => onQuestionTap?.call(sticker) : null,
        );
      case StickerType.hashtag:
        return _pill('#${sticker.data['text'] ?? ''}', Icons.tag_rounded);
      case StickerType.mention:
        return _pill(
          '@${sticker.data['text'] ?? ''}',
          Icons.alternate_email_rounded,
        );
      case StickerType.location:
        return _pill(
          sticker.data['text']?.toString() ?? '',
          Icons.location_on_rounded,
        );
      case StickerType.music:
        return _pill(
          sticker.data['text']?.toString() ?? '',
          Icons.music_note_rounded,
        );
      case StickerType.gif:
        return Text(
          sticker.data['text']?.toString() ?? '🎬',
          style: const TextStyle(fontSize: 56),
        );
      case StickerType.text:
        return _TextSticker(text: sticker.data['text']?.toString() ?? '');
    }
  }

  static Widget _pill(String text, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppIconSize.sm, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppType.label,
            fontWeight: AppType.bold,
          ),
        ),
      ],
    ),
  );
}

class _StickerCard extends StatelessWidget {
  const _StickerCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TextSticker extends StatelessWidget {
  const _TextSticker({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: AppType.headline,
          fontWeight: AppType.bold,
        ),
      ),
    );
  }
}

class _PollSticker extends ConsumerWidget {
  const _PollSticker({
    required this.storyId,
    required this.sticker,
    required this.interactive,
  });

  final String storyId;
  final StorySticker sticker;
  final bool interactive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = sticker.data['question']?.toString() ?? '';
    final options =
        (sticker.data['options'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        ['A', 'B'];
    final agg = ref
        .watch(
          stickerAggregateProvider((storyId: storyId, stickerId: sticker.id)),
        )
        .valueOrNull;
    final mine = ref
        .watch(
          myStickerResponseProvider((storyId: storyId, stickerId: sticker.id)),
        )
        .valueOrNull;
    final counts = (agg?['counts'] as Map<String, dynamic>?) ?? const {};
    final total = counts.values.fold<int>(
      0,
      (s, v) => s + ((v as num?)?.toInt() ?? 0),
    );
    final voted = mine != null;
    final myOption = (mine?['option'] as num?)?.toInt();

    return _StickerCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (question.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                question,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppType.subhead,
                  fontWeight: AppType.bold,
                ),
              ),
            ),
          for (var i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: _PollOption(
                label: options[i],
                pct: total == 0
                    ? 0
                    : ((counts['$i'] as num?)?.toInt() ?? 0) / total,
                showPct: voted,
                selected: myOption == i,
                onTap: interactive
                    ? () {
                        final uid = ref
                            .read(authStateProvider)
                            .valueOrNull
                            ?.uid;
                        if (uid != null) {
                          ref
                              .read(storyRepositoryProvider)
                              .votePoll(
                                storyId: storyId,
                                stickerId: sticker.id,
                                uid: uid,
                                optionIndex: i,
                              );
                        }
                      }
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _PollOption extends StatelessWidget {
  const _PollOption({
    required this.label,
    required this.pct,
    required this.showPct,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double pct;
  final bool showPct;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.layer3,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          if (showPct)
            FractionallySizedBox(
              widthFactor: pct.clamp(0.0, 1.0),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.35)
                      : AppColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ),
          SizedBox(
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: AppType.body,
                        fontWeight: selected ? AppType.bold : AppType.medium,
                      ),
                    ),
                  ),
                  if (showPct)
                    Text(
                      '${(pct * 100).round()}%',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppType.label,
                        fontWeight: AppType.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderSticker extends ConsumerStatefulWidget {
  const _SliderSticker({
    required this.storyId,
    required this.sticker,
    required this.interactive,
  });

  final String storyId;
  final StorySticker sticker;
  final bool interactive;

  @override
  ConsumerState<_SliderSticker> createState() => _SliderStickerState();
}

class _SliderStickerState extends ConsumerState<_SliderSticker> {
  double _value = 0.5;

  @override
  Widget build(BuildContext context) {
    final emoji = widget.sticker.data['emoji']?.toString() ?? '😍';
    final question = widget.sticker.data['question']?.toString() ?? '';
    final agg = ref
        .watch(
          stickerAggregateProvider((
            storyId: widget.storyId,
            stickerId: widget.sticker.id,
          )),
        )
        .valueOrNull;
    final n = (agg?['n'] as num?)?.toInt() ?? 0;
    final avg = n == 0 ? null : ((agg?['sum'] as num?)?.toDouble() ?? 0) / n;

    return _StickerCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (question.isNotEmpty)
            Text(
              question,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppType.subhead,
                fontWeight: AppType.bold,
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.layer3,
                    thumbColor: AppColors.primary,
                    overlayShape: SliderComponentShape.noOverlay,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 12,
                    ),
                  ),
                  child: Slider(
                    value: _value,
                    onChanged: widget.interactive
                        ? (v) => setState(() => _value = v)
                        : null,
                    onChangeEnd: widget.interactive
                        ? (v) {
                            final uid = ref
                                .read(authStateProvider)
                                .valueOrNull
                                ?.uid;
                            if (uid != null) {
                              ref
                                  .read(storyRepositoryProvider)
                                  .respondSlider(
                                    storyId: widget.storyId,
                                    stickerId: widget.sticker.id,
                                    uid: uid,
                                    value: v,
                                  );
                            }
                          }
                        : null,
                  ),
                ),
              ),
              Text(emoji, style: const TextStyle(fontSize: 22)),
            ],
          ),
          if (avg != null)
            Text(
              '${tr('Trung bình: ', 'Average: ')}${(avg * 100).round()}%',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppType.small,
              ),
            ),
        ],
      ),
    );
  }
}

class _QuizSticker extends StatefulWidget {
  const _QuizSticker({required this.sticker, required this.interactive});
  final StorySticker sticker;
  final bool interactive;

  @override
  State<_QuizSticker> createState() => _QuizStickerState();
}

class _QuizStickerState extends State<_QuizSticker> {
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final question = widget.sticker.data['question']?.toString() ?? '';
    final options =
        (widget.sticker.data['options'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        ['A', 'B'];
    final correct = (widget.sticker.data['correctIndex'] as num?)?.toInt() ?? 0;

    return _StickerCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (question.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                question,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppType.subhead,
                  fontWeight: AppType.bold,
                ),
              ),
            ),
          for (var i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: GestureDetector(
                onTap: widget.interactive && _picked == null
                    ? () => setState(() => _picked = i)
                    : null,
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _picked == null
                        ? AppColors.layer3
                        : (i == correct
                              ? AppColors.success.withValues(alpha: 0.25)
                              : (i == _picked
                                    ? AppColors.danger.withValues(alpha: 0.25)
                                    : AppColors.layer3)),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    options[i],
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppType.body,
                      fontWeight: AppType.medium,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuestionSticker extends StatelessWidget {
  const _QuestionSticker({required this.sticker, required this.onTap});
  final StorySticker sticker;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final prompt = sticker.data['prompt']?.toString() ?? '';
    return GestureDetector(
      onTap: onTap,
      child: _StickerCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              prompt,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppType.subhead,
                fontWeight: AppType.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.layer3,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                tr('Trả lời...', 'Answer...'),
                style: const TextStyle(color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownSticker extends StatefulWidget {
  const _CountdownSticker({required this.sticker});
  final StorySticker sticker;

  @override
  State<_CountdownSticker> createState() => _CountdownStickerState();
}

class _CountdownStickerState extends State<_CountdownSticker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.sticker.data['title']?.toString() ?? '';
    final endMs = (widget.sticker.data['endAt'] as num?)?.toInt() ?? 0;
    final end = DateTime.fromMillisecondsSinceEpoch(endMs);
    final left = end.difference(DateTime.now());
    final done = left.isNegative;
    final d = left.inDays,
        h = left.inHours % 24,
        m = left.inMinutes % 60,
        s = left.inSeconds % 60;

    return _StickerCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppType.subhead,
              fontWeight: AppType.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            done ? tr('Đã kết thúc', 'Ended') : '${d}d ${h}h ${m}m ${s}s',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: AppType.title,
              fontWeight: AppType.heavy,
            ),
          ),
        ],
      ),
    );
  }
}
