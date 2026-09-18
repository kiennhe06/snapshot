import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/core/i18n/i18n.dart';
import 'package:snapshot/widgets/components/components.dart';
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
        _snack(tr('Đã lưu hồ sơ.', 'Profile saved.'));
        context.pop();
      }
    } on StateError catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(
        tr(
          'Không lưu được hồ sơ. Vui lòng thử lại.',
          'Could not save profile. Please try again.',
        ),
      );
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

    final ImageProvider? avatarImage = _pickedAvatar != null
        ? FileImage(_pickedAvatar!)
        : (_currentPhotoUrl != null
              ? CachedNetworkImageProvider(_currentPhotoUrl!)
              : null);

    return AppScaffold(
      topBar: AppTopBar(
        title: tr('Chỉnh sửa hồ sơ', 'Edit profile'),
        showBack: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: PressScale(
                onTap: _pickAvatar,
                child: AppAvatar(
                  imageProvider: avatarImage,
                  radius: 48,
                  icon: Icons.add_a_photo_rounded,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: AppButton(
                label: tr('Đổi ảnh đại diện', 'Change profile photo'),
                variant: AppButtonVariant.ghost,
                fullWidth: false,
                height: 40,
                onPressed: _pickAvatar,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _name,
              label: tr('Tên hiển thị', 'Display name'),
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _username,
              label: 'Username',
              icon: Icons.alternate_email_rounded,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _bio,
              label: tr('Tiểu sử', 'Bio'),
              icon: Icons.notes_rounded,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _website,
              label: 'Website',
              icon: Icons.link_rounded,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: tr('Lưu', 'Save'),
              isLoading: _loading,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
