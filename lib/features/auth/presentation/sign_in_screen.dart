import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:snapshot/app/theme.dart';
import 'package:snapshot/core/constants.dart';
import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/core/i18n/i18n.dart';
import 'package:snapshot/core/utils/auth_error.dart';
import 'package:snapshot/widgets/components/components.dart';
import '../providers/auth_providers.dart';
import 'auth_flow.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

/// Dev-only credentials, supplied at build time via
/// `--dart-define=DEV_EMAIL=... --dart-define=DEV_PASSWORD=...`.
/// Empty by default so nothing sensitive is ever committed (public repo).
const String _devEmail = String.fromEnvironment('DEV_EMAIL');
const String _devPassword = String.fromEnvironment('DEV_PASSWORD');

class _SignInScreenState extends ConsumerState<SignInScreen> {
  static const _emailKey = 'saved_email_v1';
  static const _pwKey = 'saved_password_v1';

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _remember = true;

  @override
  void initState() {
    super.initState();
    _restoreCredentials();
  }

  /// Prefills (and auto-signs-in with) locally remembered credentials, so the
  /// user doesn't retype them after an app restart/reset. Falls back to the
  /// debug --dart-define account when nothing is saved.
  Future<void> _restoreCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_emailKey);
      final pw = prefs.getString(_pwKey);
      if (email != null && email.isNotEmpty) {
        _email.text = email;
        _password.text = pw ?? '';
        if (mounted) setState(() {});
        if ((pw ?? '').isNotEmpty) {
          _signInEmail();
          return;
        }
      }
    } catch (_) {}

    if (kDebugMode && _devEmail.isNotEmpty) {
      _email.text = _devEmail;
      _password.text = _devPassword;
      if (mounted) setState(() {});
      if (_devPassword.isNotEmpty) _signInEmail();
    }
  }

  Future<void> _persistCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_remember) {
        await prefs.setString(_emailKey, _email.text.trim());
        await prefs.setString(_pwKey, _password.text);
      } else {
        await prefs.remove(_emailKey);
        await prefs.remove(_pwKey);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    showAppToast(context, message);
  }

  Future<void> _signInEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final service = ref.read(authServiceProvider);
      final cred = await service.signInWithEmail(_email.text, _password.text);
      final user = cred.user;
      if (user != null) {
        await _persistCredentials();
        await handlePostSignIn(ref, user: user, signInMethod: 'password');
      }
    } on FirebaseAuthMultiFactorException catch (e) {
      // 2FA required: route to the challenge screen with the resolver.
      if (mounted) context.push(Routes.mfaChallenge, extra: e.resolver);
    } on FirebaseAuthException catch (e) {
      // The keychain error is non-fatal (auth still lands in memory); the
      // auth-state stream will navigate. Don't scare the user with it.
      if (!isKeychainError(e)) _snack(authErrorMessage(e));
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
      if (!isKeychainError(e)) _snack(authErrorMessage(e));
    } catch (e) {
      if (!isKeychainError(e)) _snack(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xxl),
                  Icon(
                    Icons.camera_alt_rounded,
                    size: 64,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Snapshot',
                    textAlign: TextAlign.center,
                    style: brandWordmark(context, size: 40),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  AppTextField(
                    controller: _email,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    icon: Icons.email_outlined,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
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
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      PressScale(
                        onTap: () => setState(() => _remember = !_remember),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _remember
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 20,
                              color: _remember
                                  ? AppColors.primary
                                  : AppColors.textTertiary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              tr('Ghi nhớ đăng nhập', 'Remember me'),
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: AppType.label,
                                fontWeight: AppType.medium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppButton(
                        label: tr('Quên mật khẩu?', 'Forgot password?'),
                        variant: AppButtonVariant.ghost,
                        fullWidth: false,
                        height: 44,
                        onPressed: () => context.push(Routes.forgotPassword),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: tr('Đăng nhập', 'Sign in'),
                    isLoading: _loading,
                    onPressed: _signInEmail,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: tr('Đăng nhập bằng Google', 'Sign in with Google'),
                    variant: AppButtonVariant.secondary,
                    icon: Icons.g_mobiledata,
                    onPressed: _loading ? null : _signInGoogle,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: tr(
                      'Đăng nhập bằng số điện thoại',
                      'Sign in with phone number',
                    ),
                    variant: AppButtonVariant.secondary,
                    icon: Icons.phone_outlined,
                    onPressed: _loading
                        ? null
                        : () => context.push(Routes.phoneSignIn),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        tr('Chưa có tài khoản?', "Don't have an account?"),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppType.subhead,
                        ),
                      ),
                      AppButton(
                        label: tr('Đăng ký', 'Sign up'),
                        variant: AppButtonVariant.ghost,
                        fullWidth: false,
                        height: 44,
                        onPressed: () => context.push(Routes.signUp),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
