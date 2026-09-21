import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:snapshot/app/theme.dart';
import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/core/i18n/i18n.dart';
import 'package:snapshot/core/utils/auth_error.dart';
import 'package:snapshot/widgets/components/components.dart';
import '../providers/auth_providers.dart';
import 'auth_flow.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
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
      final service = ref.read(authServiceProvider);
      final cred = await service.signUpWithEmail(_email.text, _password.text);
      final user = cred.user;
      if (user != null) {
        // Set the display name before the profile doc is created.
        await user.updateDisplayName(_name.text.trim());
        await user.reload();
        final fresh = service.currentUser ?? user;
        await handlePostSignIn(ref, user: fresh, signInMethod: 'password');
      }
    } on FirebaseAuthException catch (e) {
      // Keychain persistence error is non-fatal; the account is created.
      if (!isKeychainError(e)) _snack(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: AppTopBar(
        title: tr('Tạo tài khoản', 'Create account'),
        showBack: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Snapshot',
                textAlign: TextAlign.center,
                style: brandWordmark(context, size: 40),
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppTextField(
                controller: _name,
                label: tr('Tên hiển thị', 'Display name'),
                icon: Icons.person_outline,
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? tr('Vui lòng nhập tên', 'Please enter your name')
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _email,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                icon: Icons.email_outlined,
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || !v.contains('@'))
                    ? tr('Email không hợp lệ', 'Invalid email')
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _password,
                label: tr('Mật khẩu', 'Password'),
                obscureText: _obscure,
                icon: Icons.lock_outline,
                textInputAction: TextInputAction.next,
                suffix: AppIconButton(
                  icon: _obscure ? Icons.visibility_off : Icons.visibility,
                  onTap: () => setState(() => _obscure = !_obscure),
                ),
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
                label: tr('Nhập lại mật khẩu', 'Confirm password'),
                obscureText: _obscure,
                icon: Icons.lock_outline,
                textInputAction: TextInputAction.done,
                validator: (v) => v != _password.text
                    ? tr('Mật khẩu không khớp', 'Passwords do not match')
                    : null,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: tr('Đăng ký', 'Sign up'),
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
