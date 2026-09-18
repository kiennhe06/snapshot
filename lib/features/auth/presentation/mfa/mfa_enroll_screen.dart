import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/auth_error.dart';
import '../../data/auth_service.dart';
import '../../providers/auth_providers.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/primary_button.dart';

/// Enables SMS-based 2FA for the signed-in user.
///
/// Requires Google Cloud Identity Platform (Blaze plan) with MFA enabled — see
/// the Console checklist. Without it, enrollment throws operation-not-allowed.
class MfaEnrollScreen extends ConsumerStatefulWidget {
  const MfaEnrollScreen({super.key});

  @override
  ConsumerState<MfaEnrollScreen> createState() => _MfaEnrollScreenState();
}

class _MfaEnrollScreenState extends ConsumerState<MfaEnrollScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _loading = false;
  PhoneVerification? _verification;

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
    if (!_phone.text.trim().startsWith('+')) {
      _snack('Nhập số theo định dạng quốc tế, ví dụ +84901234567.');
      return;
    }
    setState(() => _loading = true);
    try {
      final verification = await ref
          .read(authServiceProvider)
          .startMfaEnrollment(
            phoneNumber: _phone.text,
            onFailed: (e) => _snack(authErrorMessage(e)),
          );
      if (mounted) setState(() => _verification = verification);
    } on FirebaseAuthException catch (e) {
      _snack(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    final verification = _verification;
    if (verification == null) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authServiceProvider)
          .confirmMfaEnrollment(
            verificationId: verification.verificationId,
            smsCode: _code.text,
          );
      // Reflect MFA status on the profile (best-effort).
      final uid = ref.read(authServiceProvider).currentUser?.uid;
      if (uid != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'mfaEnabled': true,
          }, SetOptions(merge: true));
        } catch (_) {}
      }
      if (!mounted) return;
      _snack('Đã bật xác thực 2 lớp.');
      context.pop();
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
      appBar: AppBar(title: const Text('Bật xác thực 2 lớp')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Thêm số điện thoại làm lớp bảo mật thứ hai. Mỗi lần đăng nhập '
                'bạn sẽ cần nhập thêm mã OTP.',
              ),
              const SizedBox(height: 20),
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
                label: isCodeStep ? 'Xác nhận & bật 2FA' : 'Gửi mã OTP',
                isLoading: _loading,
                onPressed: isCodeStep ? _confirm : _sendCode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
