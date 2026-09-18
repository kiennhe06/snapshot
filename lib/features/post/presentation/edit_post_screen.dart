import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/post.dart';
import '../../auth/presentation/widgets/primary_button.dart';
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
        _snack('Đã cập nhật bài viết.');
        context.pop();
      }
    } catch (e) {
      _snack('Không cập nhật được bài viết.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editAlt(int index) async {
    final c = TextEditingController(text: _altTexts[index]);
    final r = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Alt text ảnh ${index + 1}'),
        content: TextField(controller: c, maxLines: 3),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (r != null) setState(() => _altTexts[index] = r);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa bài viết')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _caption,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Chú thích',
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
                if (r != null) setState(() => _tagged = r);
              },
            ),
            const Divider(),
            for (var i = 0; i < _altTexts.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.accessibility_new),
                title: Text('Alt text ảnh ${i + 1}'),
                subtitle: Text(
                  _altTexts[i].isEmpty ? 'Chưa có mô tả' : _altTexts[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.edit, size: 18),
                onTap: () => _editAlt(i),
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
              label: 'Lưu thay đổi',
              isLoading: _loading,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
