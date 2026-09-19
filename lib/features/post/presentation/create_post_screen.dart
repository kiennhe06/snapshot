import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/core/i18n/i18n.dart';
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

  // Background autosave state.
  Timer? _autosave;
  bool _saving = false;
  DateTime? _savedAt;
  bool _published = false;

  @override
  void initState() {
    super.initState();
    _caption.addListener(_scheduleAutosave);
    _location.addListener(_scheduleAutosave);
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
    _autosave?.cancel();
    _caption.dispose();
    _location.dispose();
    super.dispose();
  }

  // ---- Autosave draft ---------------------------------------------------------

  bool get _hasContent =>
      _items.isNotEmpty || _caption.text.trim().isNotEmpty;

  PostDraft _buildDraft() => PostDraft(
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

  /// Debounced background save — no navigation, no toast.
  void _scheduleAutosave() {
    _autosave?.cancel();
    if (!_hasContent || _published) return;
    if (mounted) setState(() => _saving = true);
    _autosave = Timer(const Duration(milliseconds: 800), _autosaveNow);
  }

  Future<void> _autosaveNow() async {
    _autosave?.cancel();
    if (!_hasContent || _published) return;
    await ref.read(draftRepositoryProvider).saveDraft(_buildDraft());
    ref.invalidate(draftsProvider);
    if (mounted) {
      setState(() {
        _saving = false;
        _savedAt = DateTime.now();
      });
    }
  }

  /// Marks any change to non-text fields (media/tag/collab/toggles) dirty.
  void _markChanged() => _scheduleAutosave();

  void _snack(String m) {
    if (!mounted) return;
    showAppToast(context, m);
  }

  // ---- Media picking / capture ------------------------------------------------

  Future<void> _addMediaSheet() async {
    await showAppMenu(context, [
      AppMenuAction(
        icon: Icons.photo_library_outlined,
        label: tr(
          'Chọn ảnh từ thư viện (nhiều ảnh)',
          'Choose photos from library (multiple)',
        ),
        onTap: _pickImages,
      ),
      AppMenuAction(
        icon: Icons.photo_camera_outlined,
        label: tr('Chụp ảnh mới', 'Take a new photo'),
        onTap: () => _capture(isVideo: false),
      ),
      AppMenuAction(
        icon: Icons.video_library_outlined,
        label: tr('Chọn video từ thư viện', 'Choose video from library'),
        onTap: _pickVideo,
      ),
      AppMenuAction(
        icon: Icons.videocam_outlined,
        label: tr('Quay video mới', 'Record a new video'),
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
    _markChanged();
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    setState(
      () => _items.add(DraftMedia(file: File(picked.path), isVideo: true)),
    );
    _markChanged();
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
    _markChanged();
  }

  // ---- Per-item actions -------------------------------------------------------

  Future<void> _itemActions(int index) async {
    final item = _items[index];
    await showAppMenu(context, [
      if (!item.isVideo)
        AppMenuAction(
          icon: Icons.tune,
          label: tr(
            'Chỉnh sửa ảnh (cắt, lọc, sáng/màu)',
            'Edit photo (crop, filter, brightness/color)',
          ),
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
              _markChanged();
            }
          },
        ),
      AppMenuAction(
        icon: Icons.accessibility_new,
        label: tr('Alt text (mô tả ảnh)', 'Alt text (image description)'),
        onTap: () => _editAltText(index),
      ),
      AppMenuAction(
        icon: Icons.delete_outline,
        label: tr('Xoá khỏi bài', 'Remove from post'),
        destructive: true,
        onTap: () {
          setState(() => _items.removeAt(index));
          _markChanged();
        },
      ),
    ]);
  }

  Future<void> _editAltText(int index) async {
    final controller = TextEditingController(text: _items[index].altText);
    final result = await _showAltTextDialog(
      context,
      title: tr('Alt text', 'Alt text'),
      controller: controller,
      hint: tr(
        'Mô tả nội dung ảnh cho người khiếm thị',
        'Describe the image for visually impaired users',
      ),
    );
    if (result != null) {
      setState(() => _items[index].altText = result);
      _markChanged();
    }
  }

  // ---- Publish / draft --------------------------------------------------------

  Future<void> _publish() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    if (_items.isEmpty) {
      _snack(
        tr(
          'Hãy thêm ít nhất một ảnh hoặc video.',
          'Add at least one photo or video.',
        ),
      );
      return;
    }
    _published = true;
    _autosave?.cancel();
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
      ref.invalidate(draftsProvider);
      if (mounted) {
        _snack(tr('Đã đăng bài.', 'Post published.'));
        context.pop();
      }
    } catch (e) {
      _published = false;
      _snack(
        tr(
          'Đăng bài thất bại. Kiểm tra kết nối.',
          'Failed to publish. Check your connection.',
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Back handling: an in-progress post is autosaved, so on exit we ask whether
  /// to keep the draft or discard it.
  Future<void> _handleBack() async {
    if (_published || !_hasContent) {
      if (mounted) context.pop();
      return;
    }
    final keep = await _confirmExit();
    if (keep == null) return; // cancelled
    if (keep) {
      await _autosaveNow();
    } else {
      _autosave?.cancel();
      await ref.read(draftRepositoryProvider).deleteDraft(_draftId);
      ref.invalidate(draftsProvider);
    }
    if (mounted) context.pop();
  }

  /// Returns true = keep draft, false = discard, null = cancel.
  Future<bool?> _confirmExit() {
    return showAppSheet<bool>(
      context,
      builder: (sheetCtx) => AppSheetSurface(
        title: tr('Lưu bản nháp này?', 'Save this draft?'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Text(
                tr(
                  'Bạn có thể tiếp tục sau từ mục Bản nháp.',
                  'You can finish it later from Drafts.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppType.subhead,
                ),
              ),
            ),
            AppButton(
              label: tr('Lưu nháp', 'Save draft'),
              onPressed: () => Navigator.pop(sheetCtx, true),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: tr('Bỏ bài', 'Discard'),
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.pop(sheetCtx, false),
            ),
          ],
        ),
      ),
    );
  }

  // ---- UI ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: AppScaffold(
        topBar: AppTopBar(
          title: tr('Bài viết mới', 'New post'),
          showBack: true,
          onBack: _handleBack,
          actions: [_DraftStatus(saving: _saving, savedAt: _savedAt)],
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // PRIMARY — media + caption
            _mediaSection(),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              controller: _caption,
              label: tr('Chú thích', 'Caption'),
              hint: tr(
                'Viết chú thích... (dùng #hashtag)',
                'Write a caption... (use #hashtag)',
              ),
              maxLines: 4,
            ),
            const SizedBox(height: AppSpacing.xl),

            // SECONDARY — add to your post
            _sectionLabel(tr('Thêm vào bài viết', 'Add to your post')),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                children: [
                  AppTile(
                    leading: Icon(
                      Icons.location_on_outlined,
                      color: AppColors.textSecondary,
                      size: AppIconSize.md,
                    ),
                    title: tr('Địa điểm', 'Location'),
                    subtitle: _location.text.isEmpty
                        ? tr('Thêm địa điểm', 'Add a place')
                        : _location.text,
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textTertiary,
                    ),
                    onTap: _editLocation,
                  ),
                  AppTile(
                    leading: Icon(
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
                      if (r != null) {
                        setState(
                          () => _tagged
                            ..clear()
                            ..addAll(r),
                        );
                        _markChanged();
                      }
                    },
                  ),
                  AppTile(
                    leading: Icon(
                      Icons.group_add_outlined,
                      color: AppColors.textSecondary,
                      size: AppIconSize.md,
                    ),
                    title: tr('Mời đồng tác giả', 'Invite collaborators'),
                    trailing: _CountBadge(count: _coAuthors.length),
                    onTap: () async {
                      final r = await showUserMultiPicker(
                        context,
                        title: tr('Chọn đồng tác giả', 'Choose collaborators'),
                        initial: _coAuthors,
                      );
                      if (r != null) {
                        setState(
                          () => _coAuthors
                            ..clear()
                            ..addAll(r),
                        );
                        _markChanged();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ADVANCED — folded into a sheet
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: AppTile(
                leading: Icon(
                  Icons.tune_rounded,
                  color: AppColors.textSecondary,
                  size: AppIconSize.md,
                ),
                title: tr('Cài đặt nâng cao', 'Advanced settings'),
                subtitle: _advancedSummary(),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                ),
                onTap: _openAdvanced,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            AppButton(
              label: tr('Chia sẻ', 'Share'),
              isLoading: _loading,
              onPressed: _publish,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: AppSpacing.sm, bottom: AppSpacing.sm),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        color: AppColors.textSecondary,
        fontSize: AppType.label,
        fontWeight: AppType.bold,
        letterSpacing: 0.8,
      ),
    ),
  );

  String _advancedSummary() {
    final parts = <String>[
      _commentsDisabled
          ? tr('Tắt bình luận', 'Comments off')
          : tr('Cho phép bình luận', 'Comments on'),
      _likesHidden
          ? tr('Ẩn lượt thích', 'Likes hidden')
          : tr('Hiện lượt thích', 'Likes shown'),
    ];
    return parts.join(' · ');
  }

  Future<void> _editLocation() async {
    final controller = TextEditingController(text: _location.text);
    final result = await showAppSheet<String>(
      context,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: AppSheetSurface(
          title: tr('Địa điểm', 'Location'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: controller,
                label: tr('Địa điểm', 'Location'),
                hint: tr('Thêm địa điểm', 'Add a place'),
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: tr('Xong', 'Done'),
                onPressed: () => Navigator.pop(sheetCtx, controller.text),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null) setState(() => _location.text = result);
  }

  Future<void> _openAdvanced() async {
    await showAppSheet<void>(
      context,
      builder: (sheetCtx) => AppSheetSurface(
        title: tr('Cài đặt nâng cao', 'Advanced settings'),
        child: StatefulBuilder(
          builder: (_, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppToggleRow(
                label: tr('Cho phép bình luận', 'Allow comments'),
                subtitle: tr(
                  'Người khác có thể bình luận bài này.',
                  'Others can comment on this post.',
                ),
                value: !_commentsDisabled,
                onChanged: (v) {
                  setSheet(() {});
                  setState(() => _commentsDisabled = !v);
                  _markChanged();
                },
              ),
              AppToggleRow(
                label: tr('Hiện lượt thích', 'Show like count'),
                subtitle: tr(
                  'Mọi người thấy tổng lượt thích.',
                  'Everyone can see the like count.',
                ),
                value: !_likesHidden,
                onChanged: (v) {
                  setSheet(() {});
                  setState(() => _likesHidden = !v);
                  _markChanged();
                },
              ),
            ],
          ),
        ),
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
                              child: Icon(
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    size: 30,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    tr('Thêm', 'Add'),
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
      return Icon(
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
        style: TextStyle(
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
              style: TextStyle(
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

/// Top-bar autosave indicator: "Saving…" while a draft write is pending,
/// "Draft saved" once it lands. Invisible until there is something to report.
class _DraftStatus extends StatelessWidget {
  const _DraftStatus({required this.saving, required this.savedAt});

  final bool saving;
  final DateTime? savedAt;

  @override
  Widget build(BuildContext context) {
    if (!saving && savedAt == null) return const SizedBox.shrink();
    final label = saving
        ? tr('Đang lưu…', 'Saving…')
        : tr('Đã lưu nháp', 'Draft saved');
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            saving ? Icons.cloud_sync_rounded : Icons.cloud_done_rounded,
            size: AppIconSize.sm,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: AppType.label,
            ),
          ),
        ],
      ),
    );
  }
}
