import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/auth_error.dart';
import '../../data/auth_service.dart';
import '../../providers/auth_providers.dart';
import '../auth_flow.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/primary_button.dart';

/// Second-factor challenge shown when sign-in throws
/// [FirebaseAuthMultiFactorException]. Receives the resolver via GoRouter extra.
class MfaChallengeScreen extends ConsumerStatefulWidget {
  const MfaChallengeScreen({super.key, required this.resolver});

  final MultiFactorResolver resolver;

  @override
  ConsumerState<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends ConsumerState<MfaChallengeScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  bool _sending = true;
  PhoneVerification? _verification;

  @override
  void initState() {
    super.initState();
    _sendCode();
  }

  @override
  void dispose() {
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
    setState(() => _sending = true);
    try {
      final verification = await ref
          .read(authServiceProvider)
          .startMfaChallenge(
            resolver: widget.resolver,
            onFailed: (e) => _snack(authErrorMessage(e)),
          );
      if (mounted) setState(() => _verification = verification);
    } on FirebaseAuthException catch (e) {
      _snack(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirm() async {
    final verification = _verification;
    if (verification == null) return;
    setState(() => _loading = true);
    try {
      final cred = await ref
          .read(authServiceProvider)
          .confirmMfaChallenge(
            resolver: widget.resolver,
            verificationId: verification.verificationId,
            smsCode: _code.text,
          );
      final user = cred.user;
      if (user != null) {
        await handlePostSignIn(ref, user: user, signInMethod: 'password');
      }
      if (mounted) context.pop();
    } on FirebaseAuthException catch (e) {
      _snack(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xác thực 2 lớp')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Nhập mã OTP đã gửi tới số điện thoại đã đăng ký.'),
              const SizedBox(height: 20),
              if (_sending)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                AuthTextField(
                  controller: _code,
                  label: 'Mã OTP (6 số)',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.sms_outlined,
                ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Xác nhận',
                isLoading: _loading,
                onPressed: _sending ? null : _confirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
