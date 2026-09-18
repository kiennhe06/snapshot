import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/widgets/components/components.dart';
import '../../../models/post_draft.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/data/post_repository.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/post_providers.dart';
import 'media_editor_screen.dart';
import 'widgets/user_multi_picker.dart';

/// Full post composer: pick/capture media, carousel, per-image editing, caption,
/// hashtags, tagged people, location, alt text, collaborators, comment/like
/// toggles, plus save-as-draft.
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key, this.draft});

  final PostDraft? draft;

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _caption = TextEditingController();
  final _location = TextEditingController();
  final List<DraftMedia> _items = [];
  final Set<String> _tagged = {};
  final Set<String> _coAuthors = {};
  bool _commentsDisabled = false;
  bool _likesHidden = false;
  bool _loading = false;
  String _draftId = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    if (d != null) {
      _draftId = d.id;
      _caption.text = d.caption;
      _location.text = d.location ?? '';
      _tagged.addAll(d.taggedUserIds);
      _coAuthors.addAll(d.coAuthorIds);
      _commentsDisabled = d.commentsDisabled;
      _likesHidden = d.likesHidden;
      for (final it in d.items) {
        if (File(it.path).existsSync()) {
          _items.add(
            DraftMedia(
              file: File(it.path),
              isVideo: it.isVideo,
              altText: it.altText,
            ),
          );
        }
      }
    }
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

  // ---- Media picking / capture ------------------------------------------------

  Future<void> _addMediaSheet() async {
    await showAppMenu(context, [
      AppMenuAction(
        icon: Icons.photo_library_outlined,
        label: 'Chọn ảnh từ thư viện (nhiều ảnh)',
        onTap: _pickImages,
      ),
      AppMenuAction(
        icon: Icons.photo_camera_outlined,
        label: 'Chụp ảnh mới',
        onTap: () => _capture(isVideo: false),
      ),
      AppMenuAction(
        icon: Icons.video_library_outlined,
        label: 'Chọn video từ thư viện',
        onTap: _pickVideo,
      ),
      AppMenuAction(
        icon: Icons.videocam_outlined,
        label: 'Quay video mới',
        onTap: () => _capture(isVideo: true),
      ),
    ]);
  }

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1440,
      imageQuality: 90,
    );
    if (picked.isEmpty) return;
    setState(() {
      _items.addAll(
        picked.map((x) => DraftMedia(file: File(x.path), isVideo: false)),
      );
    });
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    setState(
      () => _items.add(DraftMedia(file: File(picked.path), isVideo: true)),
    );
  }

  Future<void> _capture({required bool isVideo}) async {
    final picker = ImagePicker();
    final picked = isVideo
        ? await picker.pickVideo(source: ImageSource.camera)
        : await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (picked == null) return;
    setState(
      () => _items.add(DraftMedia(file: File(picked.path), isVideo: isVideo)),
    );
  }

  // ---- Per-item actions -------------------------------------------------------

  Future<void> _itemActions(int index) async {
    final item = _items[index];
    await showAppMenu(context, [
      if (!item.isVideo)
        AppMenuAction(
          icon: Icons.tune,
          label: 'Chỉnh sửa ảnh (cắt, lọc, sáng/màu)',
          onTap: () async {
            final edited = await Navigator.of(context).push<File>(
              MaterialPageRoute(
                builder: (_) => MediaEditorScreen(source: item.file),
              ),
            );
            if (edited != null) {
              setState(
                () => _items[index] = DraftMedia(
                  file: edited,
                  isVideo: false,
                  altText: item.altText,
                ),
              );
            }
          },
        ),
      AppMenuAction(
        icon: Icons.accessibility_new,
        label: 'Alt text (mô tả ảnh)',
        onTap: () => _editAltText(index),
      ),
      AppMenuAction(
        icon: Icons.delete_outline,
        label: 'Xoá khỏi bài',
        destructive: true,
        onTap: () => setState(() => _items.removeAt(index)),
      ),
    ]);
  }

  Future<void> _editAltText(int index) async {
    final controller = TextEditingController(text: _items[index].altText);
    final result = await _showAltTextDialog(
      context,
      title: 'Alt text',
      controller: controller,
      hint: 'Mô tả nội dung ảnh cho người khiếm thị',
    );
    if (result != null) setState(() => _items[index].altText = result);
  }

  // ---- Publish / draft --------------------------------------------------------

  Future<void> _publish() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    if (_items.isEmpty) {
      _snack('Hãy thêm ít nhất một ảnh hoặc video.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(postRepositoryProvider)
          .createPost(
            uid: uid,
            caption: _caption.text,
            media: _items,
            taggedUserIds: _tagged.toList(),
            coAuthorIds: _coAuthors.toList(),
            location: _location.text,
            commentsDisabled: _commentsDisabled,
            likesHidden: _likesHidden,
          );
      // Publishing consumes the draft, if any.
      await ref.read(draftRepositoryProvider).deleteDraft(_draftId);
      if (mounted) {
        _snack('Đã đăng bài.');
        context.pop();
      }
    } catch (e) {
      _snack('Đăng bài thất bại. Kiểm tra kết nối.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveDraft() async {
    final draft = PostDraft(
      id: _draftId,
      caption: _caption.text,
      items: _items
          .map(
            (m) => DraftItem(
              path: m.file.path,
              isVideo: m.isVideo,
              altText: m.altText,
            ),
          )
          .toList(),
      location: _location.text,
      taggedUserIds: _tagged.toList(),
      coAuthorIds: _coAuthors.toList(),
      commentsDisabled: _commentsDisabled,
      likesHidden: _likesHidden,
      updatedAt: DateTime.now(),
    );
    await ref.read(draftRepositoryProvider).saveDraft(draft);
    ref.invalidate(draftsProvider);
    if (mounted) {
      _snack('Đã lưu bản nháp.');
      context.pop();
    }
  }

  // ---- UI ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: AppTopBar(
        title: 'Đăng bài',
        showBack: true,
        actions: [
          AppButton(
            label: 'Lưu nháp',
            variant: AppButtonVariant.ghost,
            fullWidth: false,
            height: 40,
            onPressed: _loading ? null : _saveDraft,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _mediaSection(),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            controller: _caption,
            label: 'Chú thích',
            hint: 'Viết chú thích... (dùng #hashtag)',
            maxLines: 4,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _location,
            label: 'Vị trí',
            hint: 'Thêm địa điểm',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                AppTile(
                  leading: const Icon(
                    Icons.person_add_alt,
                    color: AppColors.textSecondary,
                    size: AppIconSize.md,
                  ),
                  title: 'Gắn thẻ người khác',
                  trailing: _CountBadge(count: _tagged.length),
                  onTap: () async {
                    final r = await showUserMultiPicker(
                      context,
                      title: 'Gắn thẻ người khác',
                      initial: _tagged,
                    );
                    if (r != null) {
                      setState(
                        () => _tagged
                          ..clear()
                          ..addAll(r),
                      );
                    }
                  },
                ),
                AppTile(
                  leading: const Icon(
                    Icons.group_add_outlined,
                    color: AppColors.textSecondary,
                    size: AppIconSize.md,
                  ),
                  title: 'Mời đồng tác giả (collab)',
                  trailing: _CountBadge(count: _coAuthors.length),
                  onTap: () async {
                    final r = await showUserMultiPicker(
                      context,
                      title: 'Chọn đồng tác giả',
                      initial: _coAuthors,
                    );
                    if (r != null) {
                      setState(
                        () => _coAuthors
                          ..clear()
                          ..addAll(r),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                _SwitchRow(
                  label: 'Tắt bình luận',
                  value: _commentsDisabled,
                  onChanged: (v) => setState(() => _commentsDisabled = v),
                ),
                _SwitchRow(
                  label: 'Ẩn lượt thích',
                  value: _likesHidden,
                  onChanged: (v) => setState(() => _likesHidden = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: 'Đăng', isLoading: _loading, onPressed: _publish),
        ],
      ),
    );
  }

  Widget _mediaSection() {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ..._items.asMap().entries.map((e) {
            final i = e.key;
            final m = e.value;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: PressScale(
                onTap: () => _itemActions(i),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: AppRadius.brMd,
                      child: m.isVideo
                          ? Container(
                              width: 110,
                              height: 110,
                              color: AppColors.layer3,
                              child: const Icon(
                                Icons.videocam,
                                size: 40,
                                color: AppColors.textSecondary,
                              ),
                            )
                          : Image.file(
                              m.file,
                              width: 110,
                              height: 110,
                              fit: BoxFit.cover,
                            ),
                    ),
                    if (m.altText.isNotEmpty)
                      Positioned(
                        bottom: AppSpacing.xs,
                        left: AppSpacing.xs,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.textPrimary.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(AppRadius.xxs),
                          ),
                          child: const Icon(
                            Icons.accessibility_new,
                            size: AppIconSize.xs,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          // Add button — soft dashed-style rounded tile.
          PressScale(
            onTap: _addMediaSheet,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.layer3,
                borderRadius: AppRadius.brMd,
                border: Border.all(color: AppColors.borderStrong, width: 1.5),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    size: 30,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'Thêm',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppType.label,
                      fontWeight: AppType.medium,
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

/// Small pill badge showing a selection count (hidden when zero).
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
              label: 'Mô tả ảnh',
              hint: hint,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Huỷ',
                    variant: AppButtonVariant.secondary,
                    height: 48,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: 'Lưu',
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
