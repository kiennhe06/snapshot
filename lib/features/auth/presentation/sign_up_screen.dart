import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/core/i18n/i18n.dart';
import 'package:snapshot/core/utils/auth_error.dart';
import 'package:snapshot/widgets/components/components.dart';
import '../providers/auth_providers.dart';
import 'auth_flow.dart';
import 'widgets/auth_ui.dart';

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
      _snack(isKeychainError(e)
          ? tr(
              'Không lưu được phiên trên thiết bị này (lỗi keychain). Cần thêm Team trong Xcode.',
              'Could not save the session (keychain). Add a signing Team in Xcode.',
            )
          : authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: AppTopBar(showBack: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.sm),
                const AuthLogo(),
                const SizedBox(height: AppSpacing.lg),
                AuthHeadline(
                  title: tr('Tạo tài khoản mới', 'Create your account'),
                  subtitle: tr(
                    'Tham gia cộng đồng nghệ sĩ và\nbắt đầu chia sẻ sáng tạo của bạn',
                    'Join the artist community and\nstart sharing your creations',
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppTextField(
                  controller: _name,
                  label: tr('Tên hiển thị', 'Display name'),
                  icon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? tr('Vui lòng nhập tên', 'Please enter your name')
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _email,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  icon: Icons.alternate_email_rounded,
                  textInputAction: TextInputAction.next,
                  hint: 'you@example.com',
                  autofillHints: const [AutofillHints.email],
                  validator: (v) => (v == null || !v.contains('@'))
                      ? tr('Email không hợp lệ', 'Invalid email')
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _password,
                  label: tr('Mật khẩu bảo mật', 'Password'),
                  hint: '••••••••',
                  obscureText: _obscure,
                  icon: Icons.lock_outline_rounded,
                  textInputAction: TextInputAction.next,
                  suffix: AppIconButton(
                    icon: _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
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
                  hint: '••••••••',
                  obscureText: _obscure,
                  icon: Icons.lock_outline_rounded,
                  textInputAction: TextInputAction.done,
                  validator: (v) => v != _password.text
                      ? tr('Mật khẩu không khớp', 'Passwords do not match')
                      : null,
                ),
                const SizedBox(height: AppSpacing.xl),
                AuthGradientButton(
                  label: tr('Đăng ký', 'Sign up'),
                  loading: _loading,
                  onTap: _submit,
                ),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tr('Đã có tài khoản? ', 'Already have an account? '),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppType.subhead,
                      ),
                    ),
                    PressScale(
                      onTap: () => context.pop(),
                      child: Text(
                        tr('Đăng nhập', 'Sign in'),
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: AppType.subhead,
                          fontWeight: AppType.heavy,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
