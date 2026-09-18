import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/presentation/widgets/primary_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/data/post_repository.dart';
import '../../profile/providers/profile_providers.dart';

/// Minimal post composer: pick images or a video, add a caption, publish.
/// (A richer editor — filters, tags, location — comes in a later phase.)
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _caption = TextEditingController();
  final List<DraftMedia> _drafts = [];
  bool _loading = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1440,
      imageQuality: 85,
    );
    if (picked.isEmpty) return;
    setState(() {
      _drafts
        ..clear()
        ..addAll(
          picked.map((x) => DraftMedia(file: File(x.path), isVideo: false)),
        );
    });
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() {
      _drafts
        ..clear()
        ..add(DraftMedia(file: File(picked.path), isVideo: true));
    });
  }

  Future<void> _publish() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    if (_drafts.isEmpty) {
      _snack('Hãy chọn ít nhất một ảnh hoặc video.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(postRepositoryProvider)
          .createPost(uid: uid, caption: _caption.text, media: _drafts);
      if (mounted) {
        _snack('Đã đăng bài.');
        context.pop();
      }
    } catch (e) {
      _snack('Đăng bài thất bại. Kiểm tra kết nối/Storage.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng bài')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_drafts.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _drafts.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final d = _drafts[i];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: d.isVideo
                            ? Container(
                                width: 120,
                                color: Colors.black12,
                                child: const Icon(Icons.videocam, size: 40),
                              )
                            : Image.file(
                                d.file,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _pickImages,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Chọn ảnh'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _pickVideo,
                      icon: const Icon(Icons.videocam_outlined),
                      label: const Text('Chọn video'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _caption,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Viết chú thích... (dùng #hashtag)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Đăng',
                isLoading: _loading,
                onPressed: _publish,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
