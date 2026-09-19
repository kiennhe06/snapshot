import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/core/i18n/i18n.dart';
import 'package:snapshot/widgets/components/components.dart';
import '../../../core/utils/auth_error.dart';
import '../providers/profile_providers.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    showAppToast(context, message);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (mounted) {
        _snack(
          tr('Đổi mật khẩu thành công.', 'Password changed successfully.'),
        );
        context.pop();
      }
    } on FirebaseAuthException catch (e) {
      _snack(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: AppTopBar(
        title: tr('Đổi mật khẩu', 'Change password'),
        showBack: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _current,
                label: tr('Mật khẩu hiện tại', 'Current password'),
                obscureText: true,
                icon: Icons.lock_outline_rounded,
                validator: (v) => (v == null || v.isEmpty)
                    ? tr('Vui lòng nhập', 'Please enter a value')
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _next,
                label: tr('Mật khẩu mới', 'New password'),
                obscureText: true,
                icon: Icons.lock_reset_rounded,
                validator: (v) => (v == null || v.length < 6)
                    ? tr(
                        'Mật khẩu tối thiểu 6 ký tự',
                        'Password must be at least 6 characters',
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _confirm,
                label: tr('Nhập lại mật khẩu mới', 'Confirm new password'),
                obscureText: true,
                icon: Icons.lock_reset_rounded,
                validator: (v) => v != _next.text
                    ? tr('Mật khẩu không khớp', 'Passwords do not match')
                    : null,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: tr('Cập nhật', 'Update'),
                isLoading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
