import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../models/post_draft.dart';
import '../../auth/presentation/widgets/primary_button.dart';
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
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn ảnh từ thư viện (nhiều ảnh)'),
              onTap: () {
                Navigator.pop(context);
                _pickImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Chụp ảnh mới'),
              onTap: () {
                Navigator.pop(context);
                _capture(isVideo: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('Chọn video từ thư viện'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Quay video mới'),
              onTap: () {
                Navigator.pop(context);
                _capture(isVideo: true);
              },
            ),
          ],
        ),
      ),
    );
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
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!item.isVideo)
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Chỉnh sửa ảnh (cắt, lọc, sáng/màu)'),
                onTap: () async {
                  Navigator.pop(context);
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
            ListTile(
              leading: const Icon(Icons.accessibility_new),
              title: const Text('Alt text (mô tả ảnh)'),
              onTap: () {
                Navigator.pop(context);
                _editAltText(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Xoá khỏi bài'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _items.removeAt(index));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editAltText(int index) async {
    final controller = TextEditingController(text: _items[index].altText);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Alt text'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Mô tả nội dung ảnh cho người khiếm thị',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Lưu'),
          ),
        ],
      ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng bài'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _saveDraft,
            child: const Text('Lưu nháp'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _mediaSection(),
            const SizedBox(height: 16),
            TextField(
              controller: _caption,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Chú thích... (dùng #hashtag)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Vị trí',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_add_alt),
              title: const Text('Gắn thẻ người khác'),
              trailing: Text(_tagged.isEmpty ? '' : '${_tagged.length}'),
              onTap: () async {
                final r = await showUserMultiPicker(
                  context,
                  title: 'Gắn thẻ người khác',
                  initial: _tagged,
                );
                if (r != null)
                  setState(
                    () => _tagged
                      ..clear()
                      ..addAll(r),
                  );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.group_add_outlined),
              title: const Text('Mời đồng tác giả (collab)'),
              trailing: Text(_coAuthors.isEmpty ? '' : '${_coAuthors.length}'),
              onTap: () async {
                final r = await showUserMultiPicker(
                  context,
                  title: 'Chọn đồng tác giả',
                  initial: _coAuthors,
                );
                if (r != null)
                  setState(
                    () => _coAuthors
                      ..clear()
                      ..addAll(r),
                  );
              },
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tắt bình luận'),
              value: _commentsDisabled,
              onChanged: (v) => setState(() => _commentsDisabled = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ẩn lượt thích'),
              value: _likesHidden,
              onChanged: (v) => setState(() => _likesHidden = v),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Đăng',
              isLoading: _loading,
              onPressed: _publish,
            ),
          ],
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
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _itemActions(i),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: m.isVideo
                          ? Container(
                              width: 110,
                              height: 110,
                              color: Colors.black12,
                              child: const Icon(Icons.videocam, size: 40),
                            )
                          : Image.file(
                              m.file,
                              width: 110,
                              height: 110,
                              fit: BoxFit.cover,
                            ),
                    ),
                    if (m.altText.isNotEmpty)
                      const Positioned(
                        bottom: 4,
                        left: 4,
                        child: Icon(
                          Icons.accessibility_new,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          // Add button.
          GestureDetector(
            onTap: _addMediaSheet,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: const Icon(Icons.add_a_photo_outlined, size: 32),
            ),
          ),
        ],
      ),
    );
  }
}
