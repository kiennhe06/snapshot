import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/presentation/widgets/auth_text_field.dart';
import '../../auth/presentation/widgets/primary_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/profile_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _bio = TextEditingController();
  final _website = TextEditingController();
  File? _pickedAvatar;
  String? _currentPhotoUrl;
  String _originalUsername = '';
  bool _loading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    _website.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _pickedAvatar = File(picked.path));
  }

  Future<void> _save() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    setState(() => _loading = true);
    try {
      final userRepo = ref.read(userRepositoryProvider);

      // 1. Username change (transactional, enforces uniqueness).
      final newUsername = _username.text.trim().toLowerCase();
      if (newUsername.isNotEmpty && newUsername != _originalUsername) {
        await userRepo.changeUsername(
          uid: uid,
          newUsername: newUsername,
          oldUsername: _originalUsername,
        );
      }

      // 2. Avatar upload if changed.
      String? photoUrl;
      if (_pickedAvatar != null) {
        photoUrl = await ref
            .read(storageServiceProvider)
            .uploadAvatar(uid, _pickedAvatar!);
      }

      // 3. Other fields.
      await userRepo.updateProfile(
        uid: uid,
        displayName: _name.text.trim(),
        bio: _bio.text.trim(),
        website: _website.text.trim(),
        photoUrl: photoUrl,
      );

      if (mounted) {
        _snack('Đã lưu hồ sơ.');
        context.pop();
      }
    } on StateError catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Không lưu được hồ sơ. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prefill once from the profile stream.
    final profile = ref.watch(myProfileProvider).valueOrNull;
    if (!_initialized && profile != null) {
      _name.text = profile.displayName;
      _username.text = profile.username;
      _bio.text = profile.bio;
      _originalUsername = profile.username;
      _currentPhotoUrl = profile.photoUrl;
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa hồ sơ')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: CircleAvatar(
                    radius: 48,
                    backgroundImage: _pickedAvatar != null
                        ? FileImage(_pickedAvatar!)
                        : (_currentPhotoUrl != null
                                  ? CachedNetworkImageProvider(
                                      _currentPhotoUrl!,
                                    )
                                  : null)
                              as ImageProvider?,
                    child: _pickedAvatar == null && _currentPhotoUrl == null
                        ? const Icon(Icons.add_a_photo, size: 32)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _pickAvatar,
                  child: const Text('Đổi ảnh đại diện'),
                ),
              ),
              const SizedBox(height: 12),
              AuthTextField(
                controller: _name,
                label: 'Tên hiển thị',
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _username,
                label: 'Username',
                prefixIcon: Icons.alternate_email,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _bio,
                label: 'Tiểu sử',
                prefixIcon: Icons.notes,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _website,
                label: 'Website',
                prefixIcon: Icons.link,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Lưu',
                isLoading: _loading,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
