import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/core/i18n/i18n.dart';
import 'package:snapshot/widgets/components/components.dart';
import '../../../models/app_user.dart';
import '../../../models/post_draft.dart';
import '../../../models/spotify_track.dart';
import 'spotify_picker_sheet.dart';
import '../../auth/providers/auth_providers.dart';
import '../../explore/providers/search_providers.dart';
import '../../feed/providers/feed_providers.dart';
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
  int _preview = 0; // index of the large media preview
  String _visibility = 'public'; // 'public' | 'followers'
  SpotifyTrack? _music; // attached Spotify track
  String? _mentionQuery; // active @mention token being typed
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
    _caption.addListener(_updateMention);
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
      _visibility = d.visibility;
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
    visibility: _visibility,
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

  // ---- Caption mentions + hashtag suggestions ---------------------------------

  /// Detects an `@word` being typed just before the caret.
  void _updateMention() {
    final sel = _caption.selection;
    if (!sel.isValid || sel.start < 0) {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
      return;
    }
    final before = _caption.text.substring(
      0,
      sel.start.clamp(0, _caption.text.length),
    );
    final q = RegExp(r'@([\w.]{1,24})$').firstMatch(before)?.group(1);
    if (q != _mentionQuery) setState(() => _mentionQuery = q);
  }

  void _insertMention(AppUser user) {
    final sel = _caption.selection;
    final start = sel.start.clamp(0, _caption.text.length);
    final before = _caption.text.substring(0, start);
    final after = _caption.text.substring(start);
    final m = RegExp(r'@[\w.]*$').firstMatch(before);
    if (m == null) return;
    final newBefore = '${before.substring(0, m.start)}@${user.username} ';
    final newText = newBefore + after;
    _caption.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newBefore.length),
    );
    setState(() {
      _mentionQuery = null;
      _tagged.add(user.uid); // a mention also tags the person
    });
    _markChanged();
  }

  void _insertHashtag(String tag) {
    final t = _caption.text;
    final prefix = t.isEmpty || t.endsWith(' ') || t.endsWith('\n') ? '' : ' ';
    final newText = '$t$prefix#$tag ';
    _caption.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }

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
            musicTitle: _music?.name,
            musicArtist: _music?.artist,
            musicCoverUrl: _music?.coverUrl,
            musicPreviewUrl: _music?.previewUrl,
            musicUrl: _music?.spotifyUrl,
            commentsDisabled: _commentsDisabled,
            likesHidden: _likesHidden,
            visibility: _visibility,
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
              maxLength: 2200,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, right: AppSpacing.sm),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_caption.text.characters.length}/2200',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: AppType.small,
                  ),
                ),
              ),
            ),
            _captionSuggestions(),
            const SizedBox(height: AppSpacing.lg),

            // SECONDARY — interaction details & place
            _sectionLabel(tr('Chi tiết tương tác & Vị trí', 'Details & place')),
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
                  AppTile(
                    leading: Icon(
                      Icons.music_note_rounded,
                      color: _music != null
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: AppIconSize.md,
                    ),
                    title: tr('Thêm nhạc', 'Add music'),
                    subtitle: _music != null
                        ? '${_music!.name} · ${_music!.artist}'
                        : tr('Bài hát từ Spotify', 'A track from Spotify'),
                    trailing: _music != null
                        ? PressScale(
                            onTap: () {
                              setState(() => _music = null);
                              _markChanged();
                            },
                            child: Icon(
                              Icons.close_rounded,
                              color: AppColors.textTertiary,
                              size: AppIconSize.sm,
                            ),
                          )
                        : Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textTertiary,
                          ),
                    onTap: () async {
                      final t = await showSpotifyPicker(context);
                      if (t != null) {
                        setState(() => _music = t);
                        _markChanged();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ADVANCED — visible inline (only functional options)
            _sectionLabel(
              tr('Cài đặt nâng cao & Quyền riêng tư', 'Advanced & privacy'),
            ),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                children: [
                  AppTile(
                    leading: Icon(
                      _visibility == 'followers'
                          ? Icons.lock_outline_rounded
                          : Icons.public_rounded,
                      color: AppColors.textSecondary,
                      size: AppIconSize.md,
                    ),
                    title: tr('Ai có thể xem', 'Who can see this'),
                    subtitle: _visibility == 'followers'
                        ? tr('Chỉ người theo dõi', 'Followers only')
                        : tr('Công khai', 'Public'),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textTertiary,
                    ),
                    onTap: _pickVisibility,
                  ),
                  Divider(
                    height: 1,
                    indent: 52,
                    color: AppColors.borderSubtle,
                  ),
                  AppTile(
                    leading: Icon(
                      Icons.accessibility_new_rounded,
                      color: AppColors.textSecondary,
                      size: AppIconSize.md,
                    ),
                    title: tr('Văn bản thay thế (Alt)', 'Alt text'),
                    subtitle: _items.isEmpty
                        ? tr('Thêm ảnh trước', 'Add media first')
                        : (_items.any((m) => m.altText.isNotEmpty)
                              ? tr('Đã điền', 'Added')
                              : tr('Mô tả ảnh cho người khiếm thị',
                                  'Describe images')),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textTertiary,
                    ),
                    onTap: _items.isEmpty ? null : () => _editAltText(0),
                  ),
                  Divider(
                    height: 1,
                    indent: 52,
                    color: AppColors.borderSubtle,
                  ),
                  AppToggleRow(
                    icon: Icons.favorite_border_rounded,
                    label: tr('Ẩn số lượt thích', 'Hide like count'),
                    subtitle: tr(
                      'Chỉ mình bạn thấy tổng lượt thích.',
                      'Only you can see the total likes.',
                    ),
                    value: _likesHidden,
                    onChanged: (v) {
                      setState(() => _likesHidden = v);
                      _markChanged();
                    },
                  ),
                  AppToggleRow(
                    icon: Icons.mode_comment_outlined,
                    label: tr('Tắt tính năng bình luận', 'Turn off commenting'),
                    subtitle: tr(
                      'Người khác không thể bình luận bài này.',
                      'Others cannot comment on this post.',
                    ),
                    value: _commentsDisabled,
                    onChanged: (v) {
                      setState(() => _commentsDisabled = v);
                      _markChanged();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            AppButton(
              label: tr('Chia sẻ', 'Share'),
              isLoading: _loading,
              onPressed: _publish,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: tr('Hủy bài viết', 'Discard'),
              variant: AppButtonVariant.ghost,
              onPressed: _loading ? null : _handleBack,
            ),
          ],
        ),
      ),
    );
  }

  /// Below the caption: @mention results while typing `@`, otherwise real
  /// hashtag suggestions counted from recent posts.
  Widget _captionSuggestions() {
    final q = _mentionQuery;
    if (q != null && q.isNotEmpty) {
      final results = ref.watch(userSearchProvider(q)).valueOrNull ?? const [];
      if (results.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Column(
          children: [
            for (final AppUser u in results.take(5))
              PressScale(
                onTap: () => _insertMention(u),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      AppAvatar(
                        radius: 14,
                        imageProvider: u.photoUrl != null
                            ? CachedNetworkImageProvider(u.photoUrl!)
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '@${u.username}',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppType.subhead,
                          fontWeight: AppType.medium,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          u.displayName,
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
              ),
          ],
        ),
      );
    }
    // Hashtag suggestions
    final tags = ref.watch(trendingHashtagsProvider).valueOrNull ?? const [];
    if (tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Hashtag gợi ý', 'Suggested hashtags'),
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: AppType.small,
              fontWeight: AppType.medium,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final t in tags.take(8))
                PressScale(
                  onTap: () => _insertHashtag(t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.layer3,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '#$t',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: AppType.label,
                        fontWeight: AppType.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
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

  void _pickVisibility() {
    showAppMenu(context, [
      AppMenuAction(
        icon: Icons.public_rounded,
        label: tr('Công khai', 'Public'),
        onTap: () {
          setState(() => _visibility = 'public');
          _markChanged();
        },
      ),
      AppMenuAction(
        icon: Icons.lock_outline_rounded,
        label: tr('Chỉ người theo dõi', 'Followers only'),
        onTap: () {
          setState(() => _visibility = 'followers');
          _markChanged();
        },
      ),
    ]);
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

  Widget _mediaSection() {
    if (_items.isEmpty) {
      return PressScale(
        onTap: _addMediaSheet,
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.layer3,
              borderRadius: AppRadius.brLg,
              border: Border.all(color: AppColors.borderStrong, width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_a_photo_outlined,
                  size: 42,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  tr('Thêm ảnh hoặc video', 'Add photo or video'),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppType.body,
                    fontWeight: AppType.medium,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final idx = _preview.clamp(0, _items.length - 1);
    final cur = _items[idx];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Large preview
        ClipRRect(
          borderRadius: AppRadius.brLg,
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                cur.isVideo
                    ? Container(
                        color: AppColors.layer3,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.videocam_rounded,
                          size: 48,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : Image.file(cur.file, fit: BoxFit.cover),
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: _mediaPill(
                    '${idx + 1}/${_items.length} ${tr('ảnh', 'media')} · 4:5',
                  ),
                ),
                if (!cur.isVideo)
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: PressScale(
                      onTap: () => _itemActions(idx),
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          size: AppIconSize.sm,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: _mediaPill(
                    tr('${_items.length} đã chọn', '${_items.length} selected'),
                  ),
                ),
                Positioned(
                  right: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: PressScale(
                    onTap: _addMediaSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primaryBright, AppColors.primary],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            size: AppIconSize.sm,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            tr('Thêm', 'Add'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: AppType.label,
                              fontWeight: AppType.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Thumbnail strip
        SizedBox(
          height: 64,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < _items.length; i++) _thumb(i),
              PressScale(
                onTap: _addMediaSheet,
                child: Container(
                  width: 56,
                  height: 56,
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.layer3,
                    borderRadius: AppRadius.brMd,
                    border: Border.all(color: AppColors.borderStrong),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: AppColors.primary,
                    size: AppIconSize.lg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mediaPill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: AppType.small,
        fontWeight: AppType.bold,
      ),
    ),
  );

  Widget _thumb(int i) {
    final m = _items[i];
    final selected = i == _preview.clamp(0, _items.length - 1);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: PressScale(
        onTap: () => setState(() => _preview = i),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: AppRadius.brMd,
                border: Border.all(
                  color: selected ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: m.isVideo
                    ? Container(
                        width: 56,
                        height: 56,
                        color: AppColors.layer3,
                        child: Icon(
                          Icons.videocam,
                          size: 22,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : Image.file(
                        m.file,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            Positioned(
              top: -2,
              right: -2,
              child: PressScale(
                onTap: () {
                  setState(() {
                    _items.removeAt(i);
                    if (_preview >= _items.length) {
                      _preview = _items.isEmpty ? 0 : _items.length - 1;
                    }
                  });
                  _markChanged();
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 12,
                    color: Colors.white,
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
