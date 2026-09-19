import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../widgets/components/components.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/interaction_providers.dart';

/// Manage the keyword list used to hide matching comments.
class HiddenWordsScreen extends ConsumerStatefulWidget {
  const HiddenWordsScreen({super.key});

  @override
  ConsumerState<HiddenWordsScreen> createState() => _HiddenWordsScreenState();
}

class _HiddenWordsScreenState extends ConsumerState<HiddenWordsScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _save(List<String> words) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await ref.read(relationRepositoryProvider).setHiddenWords(uid, words);
  }

  @override
  Widget build(BuildContext context) {
    final words = ref.watch(hiddenWordsProvider).valueOrNull ?? const [];

    return AppScaffold(
      topBar: AppTopBar(
        title: tr('Từ khoá ẩn', 'Hidden words'),
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            tr(
              'Bình luận chứa các từ này sẽ được ẩn khỏi bài viết của bạn.',
              'Comments containing these words will be hidden from your posts.',
            ),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppType.subhead,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _input,
                  label: tr('Thêm từ khoá', 'Add a keyword'),
                  hint: tr('ví dụ: spam', 'e.g. spam'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xl),
                child: AppButton(
                  label: tr('Thêm', 'Add'),
                  fullWidth: false,
                  height: 48,
                  onPressed: () {
                    final w = _input.text.trim().toLowerCase();
                    if (w.isNotEmpty && !words.contains(w)) {
                      _save([...words, w]);
                      _input.clear();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (words.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxl),
              child: Center(
                child: Text(
                  tr('Chưa có từ khoá nào.', 'No keywords yet.'),
                  style: TextStyle(color: AppColors.textTertiary),
                ),
              ),
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final w in words)
                  Container(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.sm,
                      AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.layer3,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          w,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: AppType.label,
                            fontWeight: AppType.medium,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        PressScale(
                          onTap: () =>
                              _save(words.where((x) => x != w).toList()),
                          child: Icon(
                            Icons.close_rounded,
                            size: AppIconSize.sm,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
