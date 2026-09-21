import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      if (isKeychainError(e)) {
        // Firebase failed to persist the session to the keychain. If auth still
        // landed in memory, proceed; otherwise tell the user what to do.
        final u = ref.read(authServiceProvider).currentUser;
        if (u != null) {
          await _persistCredentials();
          await handlePostSignIn(ref, user: u, signInMethod: 'password');
        } else {
          _snack(tr(
            'Không lưu được phiên trên thiết bị này (lỗi keychain). Cần thêm Team trong Xcode để đăng nhập.',
            'Could not save the session (keychain). Add a signing Team in Xcode to sign in.',
          ));
        }
      } else {
        _snack(authErrorMessage(e));
      }
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
      _snack(_authMsg(e));
    } catch (e) {
      _snack(_authMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authMsg(Object e) => isKeychainError(e)
      ? tr(
          'Không lưu được phiên trên thiết bị này (lỗi keychain). Cần thêm Team trong Xcode.',
          'Could not save the session (keychain). Add a signing Team in Xcode.',
        )
      : authErrorMessage(e);

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    return AppScaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xxl,
          ),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  const _AuthLogo(),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    tr('Chào mừng trở lại', 'Welcome back'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppType.display,
                      fontWeight: AppType.heavy,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    tr(
                      'Đăng nhập để tiếp tục sáng tạo và kết nối\ncùng cộng đồng nghệ sĩ',
                      'Sign in to keep creating and connecting\nwith the artist community',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppType.subhead,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _FieldLabel(tr('Email', 'Email')),
                  const SizedBox(height: 6),
                  AppTextField(
                    controller: _email,
                    label: tr('Email', 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    icon: Icons.alternate_email_rounded,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    hint: 'you@example.com',
                    validator: (v) => (v == null || !v.contains('@'))
                        ? tr('Email không hợp lệ', 'Invalid email')
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _FieldLabel(tr('Mật khẩu bảo mật', 'Password')),
                  const SizedBox(height: 6),
                  AppTextField(
                    controller: _password,
                    label: tr('Mật khẩu', 'Password'),
                    obscureText: _obscure,
                    icon: Icons.lock_outline_rounded,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
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
                  const SizedBox(height: AppSpacing.md),
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
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
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
                      PressScale(
                        onTap: () => context.push(Routes.forgotPassword),
                        child: Text(
                          tr('Quên mật khẩu?', 'Forgot password?'),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: AppType.label,
                            fontWeight: AppType.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _GradientAuthButton(
                    label: tr('Đăng nhập', 'Sign in'),
                    loading: _loading,
                    onTap: _signInEmail,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _OrDivider(tr('HOẶC ĐĂNG NHẬP VỚI', 'OR SIGN IN WITH')),
                  const SizedBox(height: AppSpacing.lg),
                  _SocialButton(
                    label: tr('Tiếp tục với Google', 'Continue with Google'),
                    leading: const Text(
                      'G',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4285F4),
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textTertiary,
                    ),
                    onTap: _loading ? null : _signInGoogle,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SocialButton(
                    label: tr('Đăng nhập bằng SMS OTP', 'Sign in with SMS OTP'),
                    leading: Icon(
                      Icons.sms_outlined,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    onTap: _loading
                        ? null
                        : () => context.push(Routes.phoneSignIn),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        tr('Chưa có tài khoản? ', "Don't have an account? "),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppType.subhead,
                        ),
                      ),
                      PressScale(
                        onTap: () => context.push(Routes.signUp),
                        child: Text(
                          tr('Đăng ký ngay', 'Sign up'),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: AppType.subhead,
                            fontWeight: AppType.heavy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PressScale(
                    onTap: () => ref.read(localeProvider.notifier).toggle(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.language_rounded,
                          size: 15,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          lang == AppLang.vi
                              ? 'Tiếng Việt (VN)'
                              : 'English (EN)',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: AppType.label,
                          ),
                        ),
                      ],
                    ),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      text,
      style: TextStyle(
        color: AppColors.textSecondary,
        fontSize: AppType.label,
        fontWeight: AppType.bold,
      ),
    ),
  );
}

/// Glowing brand logo used at the top of the auth screens.
class _AuthLogo extends StatelessWidget {
  const _AuthLogo();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.accent, AppColors.primary],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.5),
              blurRadius: 32,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.camera_alt_rounded,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }
}

/// "OR SIGN IN WITH" divider with hairlines on each side.
class _OrDivider extends StatelessWidget {
  const _OrDivider(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Divider(color: AppColors.borderSubtle, thickness: 1),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: AppType.caption,
              fontWeight: AppType.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        line,
      ],
    );
  }
}

/// Full-width dark social sign-in row.
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.leading,
    this.trailing,
    required this.onTap,
  });
  final String label;
  final Widget leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.layer1,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            SizedBox(width: 24, child: Center(child: leading)),
            Expanded(
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppType.subhead,
                    fontWeight: AppType.bold,
                  ),
                ),
              ),
            ),
            SizedBox(width: 24, child: Center(child: trailing)),
          ],
        ),
      ),
    );
  }
}

/// Brand-gradient primary auth button.
class _GradientAuthButton extends StatelessWidget {
  const _GradientAuthButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });
  final String label;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: loading ? null : onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.accent, AppColors.primary, AppColors.primaryBright],
          ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: AppType.headline,
                      fontWeight: AppType.heavy,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ],
              ),
      ),
    );
  }
}
