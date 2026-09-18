import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/auth_error.dart';
import '../data/auth_service.dart';
import '../providers/auth_providers.dart';
import 'auth_flow.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/primary_button.dart';

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
      _snack('Nhập số theo định dạng quốc tế, ví dụ +84901234567.');
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
              _snack('Đã gửi mã OTP đến $phone.');
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
      _snack('Mã OTP gồm 6 chữ số.');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập bằng SĐT')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                controller: _phone,
                label: 'Số điện thoại (+84...)',
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
              ),
              if (isCodeStep) ...[
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _code,
                  label: 'Mã OTP (6 số)',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.sms_outlined,
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: isCodeStep ? 'Xác nhận OTP' : 'Gửi mã OTP',
                isLoading: _loading,
                onPressed: isCodeStep ? _confirmCode : _sendCode,
              ),
              if (isCodeStep)
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() => _verification = null),
                  child: const Text('Đổi số điện thoại'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
