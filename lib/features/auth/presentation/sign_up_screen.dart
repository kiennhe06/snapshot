import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:snapshot/app/theme.dart';
import 'package:snapshot/core/design/tokens.dart';
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      _snack(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: const AppTopBar(title: 'Tạo tài khoản', showBack: true),
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
                label: 'Tên hiển thị',
                icon: Icons.person_outline,
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập tên'
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
                    ? 'Email không hợp lệ'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _password,
                label: 'Mật khẩu',
                obscureText: _obscure,
                icon: Icons.lock_outline,
                textInputAction: TextInputAction.next,
                suffix: AppIconButton(
                  icon: _obscure ? Icons.visibility_off : Icons.visibility,
                  onTap: () => setState(() => _obscure = !_obscure),
                ),
                validator: (v) => (v == null || v.length < 6)
                    ? 'Mật khẩu tối thiểu 6 ký tự'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _confirm,
                label: 'Nhập lại mật khẩu',
                obscureText: _obscure,
                icon: Icons.lock_outline,
                textInputAction: TextInputAction.done,
                validator: (v) =>
                    v != _password.text ? 'Mật khẩu không khớp' : null,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: 'Đăng ký',
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
