import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/core/i18n/i18n.dart';
import 'package:snapshot/core/utils/auth_error.dart';
import 'package:snapshot/widgets/components/components.dart';
import '../data/auth_service.dart';
import '../providers/auth_providers.dart';
import 'auth_flow.dart';

class PhoneSignInScreen extends ConsumerStatefulWidget {
  const PhoneSignInScreen({super.key});

  @override
  ConsumerState<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends ConsumerState<PhoneSignInScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _loading = false;
  PhoneVerification? _verification; // null = step 1 (enter phone)

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendCode() async {
    final phone = _phone.text.trim();
    if (!phone.startsWith('+')) {
      _snack(
        tr(
          'Nhập số theo định dạng quốc tế, ví dụ +84901234567.',
          'Enter the number in international format, e.g. +84901234567.',
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(authServiceProvider)
          .startPhoneVerification(
            phoneNumber: phone,
            onCodeSent: (verification) {
              if (!mounted) return;
              setState(() {
                _verification = verification;
                _loading = false;
              });
              _snack(
                tr('Đã gửi mã OTP đến $phone.', 'OTP code sent to $phone.'),
              );
            },
            onFailed: (error) {
              if (!mounted) return;
              setState(() => _loading = false);
              _snack(authErrorMessage(error));
            },
            onAutoVerified: (cred) async {
              final user = cred.user;
              if (user != null) {
                await handlePostSignIn(ref, user: user, signInMethod: 'phone');
              }
            },
          );
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _snack(authErrorMessage(e));
    }
  }

  Future<void> _confirmCode() async {
    final verification = _verification;
    if (verification == null) return;
    if (_code.text.trim().length < 6) {
      _snack(tr('Mã OTP gồm 6 chữ số.', 'The OTP code has 6 digits.'));
      return;
    }
    setState(() => _loading = true);
    try {
      final cred = await ref
          .read(authServiceProvider)
          .confirmPhoneCode(
            verificationId: verification.verificationId,
            smsCode: _code.text,
          );
      final user = cred.user;
      if (user != null) {
        await handlePostSignIn(ref, user: user, signInMethod: 'phone');
      }
    } on FirebaseAuthException catch (e) {
      _snack(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCodeStep = _verification != null;
    return AppScaffold(
      topBar: AppTopBar(
        title: tr('Đăng nhập bằng SĐT', 'Sign in with phone'),
        showBack: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _phone,
              label: tr('Số điện thoại (+84...)', 'Phone number (+84...)'),
              keyboardType: TextInputType.phone,
              icon: Icons.phone_outlined,
            ),
            if (isCodeStep) ...[
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _code,
                label: tr('Mã OTP (6 số)', 'OTP code (6 digits)'),
                keyboardType: TextInputType.number,
                icon: Icons.sms_outlined,
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: isCodeStep
                  ? tr('Xác nhận OTP', 'Confirm OTP')
                  : tr('Gửi mã OTP', 'Send OTP code'),
              isLoading: _loading,
              onPressed: isCodeStep ? _confirmCode : _sendCode,
            ),
            if (isCodeStep) ...[
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: tr('Đổi số điện thoại', 'Change phone number'),
                variant: AppButtonVariant.ghost,
                onPressed: _loading
                    ? null
                    : () => setState(() => _verification = null),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
