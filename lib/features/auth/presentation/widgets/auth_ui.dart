import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../widgets/components/components.dart';

/// Glowing brand logo used at the top of the auth screens.
class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key, this.icon = Icons.camera_alt_rounded});
  final IconData icon;

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
        child: Icon(icon, color: Colors.white, size: 40),
      ),
    );
  }
}

/// Centered title + subtitle block for auth screens.
class AuthHeadline extends StatelessWidget {
  const AuthHeadline({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppType.display,
            fontWeight: AppType.heavy,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppType.subhead,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Brand-gradient primary auth button (with a trailing arrow).
class AuthGradientButton extends StatelessWidget {
  const AuthGradientButton({
    super.key,
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
            colors: [
              AppColors.accent,
              AppColors.primary,
              AppColors.primaryBright,
            ],
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
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Label with a hairline on each side, e.g. "OR SIGN IN WITH".
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider(this.text, {super.key});
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
class AuthSocialButton extends StatelessWidget {
  const AuthSocialButton({
    super.key,
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
