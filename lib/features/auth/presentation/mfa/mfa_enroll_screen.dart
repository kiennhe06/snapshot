import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/core/i18n/i18n.dart';
import 'package:snapshot/core/utils/auth_error.dart';
import 'package:snapshot/widgets/components/components.dart';
import '../../data/auth_service.dart';
import '../../providers/auth_providers.dart';

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
    showAppToast(context, message);
  }

  Future<void> _sendCode() async {
    if (!_phone.text.trim().startsWith('+')) {
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
      _snack(
        tr('Đã bật xác thực 2 lớp.', 'Two-factor authentication enabled.'),
      );
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
    return AppScaffold(
      topBar: AppTopBar(
        title: tr('Bật xác thực 2 lớp', 'Enable two-factor authentication'),
        showBack: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(
                'Thêm số điện thoại làm lớp bảo mật thứ hai. Mỗi lần đăng nhập '
                    'bạn sẽ cần nhập thêm mã OTP.',
                'Add a phone number as a second security layer. Each time you '
                    'sign in you will need to enter an extra OTP code.',
              ),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppType.subhead,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
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
                  ? tr('Xác nhận & bật 2FA', 'Confirm & enable 2FA')
                  : tr('Gửi mã OTP', 'Send OTP code'),
              isLoading: _loading,
              onPressed: isCodeStep ? _confirm : _sendCode,
            ),
          ],
        ),
      ),
    );
  }
}
