import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/core/i18n/i18n.dart';
import 'package:snapshot/core/utils/auth_error.dart';
import 'package:snapshot/widgets/components/components.dart';
import '../providers/auth_providers.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).sendPasswordReset(_email.text);
      if (!mounted) return;
      showAppToast(
        context,
        tr(
          'Đã gửi email đặt lại mật khẩu. Vui lòng kiểm tra hộp thư.',
          'Password reset email sent. Please check your inbox.',
        ),
        type: AppToastType.success,
      );
      context.pop();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        showAppToast(context, authErrorMessage(e), type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: AppTopBar(
        title: tr('Quên mật khẩu', 'Forgot password'),
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
                tr(
                  'Nhập email của bạn, chúng tôi sẽ gửi liên kết đặt lại mật khẩu.',
                  'Enter your email and we will send you a password reset link.',
                ),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppType.subhead,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                controller: _email,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                icon: Icons.email_outlined,
                validator: (v) => (v == null || !v.contains('@'))
                    ? tr('Email không hợp lệ', 'Invalid email')
                    : null,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: tr('Gửi email', 'Send email'),
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
