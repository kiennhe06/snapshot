import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/utils/auth_error.dart';
import '../providers/auth_providers.dart';
import 'auth_flow.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/primary_button.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signInEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final service = ref.read(authServiceProvider);
      final cred = await service.signInWithEmail(_email.text, _password.text);
      final user = cred.user;
      if (user != null) {
        await handlePostSignIn(ref, user: user, signInMethod: 'password');
      }
    } on FirebaseAuthMultiFactorException catch (e) {
      // 2FA required: route to the challenge screen with the resolver.
      if (mounted) context.push(Routes.mfaChallenge, extra: e.resolver);
    } on FirebaseAuthException catch (e) {
      _snack(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInGoogle() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(authServiceProvider);
      final cred = await service.signInWithGoogle();
      final user = cred.user;
      if (user != null) {
        await handlePostSignIn(ref, user: user, signInMethod: 'google.com');
      }
    } on FirebaseAuthMultiFactorException catch (e) {
      if (mounted) context.push(Routes.mfaChallenge, extra: e.resolver);
    } on FirebaseAuthException catch (e) {
      _snack(authErrorMessage(e));
    } catch (e) {
      _snack(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Icon(
                      Icons.camera_alt_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Snapshot',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 32),
                    AuthTextField(
                      controller: _email,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_outlined,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Email không hợp lệ'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _password,
                      label: 'Mật khẩu',
                      obscureText: _obscure,
                      prefixIcon: Icons.lock_outline,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      suffix: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Mật khẩu tối thiểu 6 ký tự'
                          : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push(Routes.forgotPassword),
                        child: const Text('Quên mật khẩu?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    PrimaryButton(
                      label: 'Đăng nhập',
                      isLoading: _loading,
                      onPressed: _signInEmail,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _signInGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: const Text('Đăng nhập bằng Google'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () => context.push(Routes.phoneSignIn),
                      icon: const Icon(Icons.phone_outlined),
                      label: const Text('Đăng nhập bằng số điện thoại'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Chưa có tài khoản?'),
                        TextButton(
                          onPressed: () => context.push(Routes.signUp),
                          child: const Text('Đăng ký'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
