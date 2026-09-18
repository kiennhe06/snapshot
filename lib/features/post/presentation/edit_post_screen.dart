import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/core/i18n/i18n.dart';
import 'package:snapshot/widgets/components/components.dart';
import '../../../models/post.dart';
import '../../profile/providers/profile_providers.dart';
import 'widgets/user_multi_picker.dart';

/// Edits an existing post's text and settings (media stays the same).
class EditPostScreen extends ConsumerStatefulWidget {
  const EditPostScreen({super.key, required this.post});

  final Post post;

  @override
  ConsumerState<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends ConsumerState<EditPostScreen> {
  late final TextEditingController _caption;
  late final TextEditingController _location;
  late List<String> _altTexts;
  late Set<String> _tagged;
  late bool _commentsDisabled;
  late bool _likesHidden;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.post;
    _caption = TextEditingController(text: p.caption);
    _location = TextEditingController(text: p.location ?? '');
    _altTexts = p.media.map((m) => m.altText).toList();
    _tagged = {...p.taggedUserIds};
    _commentsDisabled = p.commentsDisabled;
    _likesHidden = p.likesHidden;
  }

  @override
  void dispose() {
    _caption.dispose();
    _location.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(postRepositoryProvider)
          .updatePost(
            postId: widget.post.postId,
            caption: _caption.text,
            location: _location.text,
            taggedUserIds: _tagged.toList(),
            altTexts: _altTexts,
            commentsDisabled: _commentsDisabled,
            likesHidden: _likesHidden,
          );
      if (mounted) {
        _snack(tr('Đã cập nhật bài viết.', 'Post updated.'));
        context.pop();
      }
    } catch (e) {
      _snack(tr('Không cập nhật được bài viết.', 'Could not update the post.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editAlt(int index) async {
    final c = TextEditingController(text: _altTexts[index]);
    final r = await _showAltTextDialog(
      context,
      title: tr('Alt text ảnh ${index + 1}', 'Alt text image ${index + 1}'),
      controller: c,
    );
    if (r != null) setState(() => _altTexts[index] = r);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: AppTopBar(
        title: tr('Chỉnh sửa bài viết', 'Edit post'),
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppTextField(
            controller: _caption,
            label: tr('Chú thích', 'Caption'),
            hint: tr('Viết chú thích...', 'Write a caption...'),
            maxLines: 4,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _location,
            label: tr('Vị trí', 'Location'),
            hint: tr('Thêm địa điểm', 'Add a place'),
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: AppTile(
              leading: const Icon(
                Icons.person_add_alt,
                color: AppColors.textSecondary,
                size: AppIconSize.md,
              ),
              title: tr('Gắn thẻ người khác', 'Tag people'),
              trailing: _CountBadge(count: _tagged.length),
              onTap: () async {
                final r = await showUserMultiPicker(
                  context,
                  title: tr('Gắn thẻ người khác', 'Tag people'),
                  initial: _tagged,
                );
                if (r != null) setState(() => _tagged = r);
              },
            ),
          ),
          if (_altTexts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                children: [
                  for (var i = 0; i < _altTexts.length; i++)
                    AppTile(
                      leading: const Icon(
                        Icons.accessibility_new,
                        color: AppColors.textSecondary,
                        size: AppIconSize.md,
                      ),
                      title: tr(
                        'Alt text ảnh ${i + 1}',
                        'Alt text image ${i + 1}',
                      ),
                      subtitle: _altTexts[i].isEmpty
                          ? tr('Chưa có mô tả', 'No description yet')
                          : _altTexts[i],
                      trailing: const Icon(
                        Icons.edit,
                        size: AppIconSize.sm,
                        color: AppColors.textTertiary,
                      ),
                      onTap: () => _editAlt(i),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                _SwitchRow(
                  label: tr('Tắt bình luận', 'Turn off commenting'),
                  value: _commentsDisabled,
                  onChanged: (v) => setState(() => _commentsDisabled = v),
                ),
                _SwitchRow(
                  label: tr('Ẩn lượt thích', 'Hide like count'),
                  value: _likesHidden,
                  onChanged: (v) => setState(() => _likesHidden = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: tr('Lưu thay đổi', 'Save changes'),
            isLoading: _loading,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

/// Small pill badge showing a selection count (chevron when zero).
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textTertiary,
        size: AppIconSize.md,
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: AppType.label,
          fontWeight: AppType.bold,
        ),
      ),
    );
  }
}

/// Custom labelled toggle row (replaces Material SwitchListTile). Keeps the
/// Material [Switch] primitive but tinted with brand tokens.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppType.subhead,
                fontWeight: AppType.medium,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: AppColors.borderStrong,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

/// Token-styled alt-text editor dialog (rounded container + [AppTextField]).
Future<String?> _showAltTextDialog(
  BuildContext context, {
  required String title,
  required TextEditingController controller,
  String? hint,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.xxl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.layer1,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.overlay,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppType.title,
                fontWeight: AppType.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: controller,
              label: tr('Mô tả ảnh', 'Image description'),
              hint: hint,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: tr('Huỷ', 'Cancel'),
                    variant: AppButtonVariant.secondary,
                    height: 48,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: tr('Lưu', 'Save'),
                    height: 48,
                    onPressed: () => Navigator.pop(context, controller.text),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
