import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/design/display_theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../widgets/components/components.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/profile_providers.dart';

/// Grouped account settings (Concept B, level 2): privacy, security and app
/// preferences — the rarely-used items pulled out of the profile hub.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myProfileProvider).valueOrNull;
    final isPrivate = me?.isPrivate ?? false;
    final isDark = ref.watch(displayThemeProvider) == DisplaySkin.dark;
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;

    return AppScaffold(
      topBar: AppTopBar(
        title: tr('Cài đặt & quyền riêng tư', 'Settings & privacy'),
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: [
          _SectionHeader(
            icon: Icons.lock_outline_rounded,
            title: tr('Quyền riêng tư', 'Privacy'),
          ),
          _GroupCard(
            children: [
              _SettingRow(
                icon: isPrivate ? Icons.lock_rounded : Icons.public_rounded,
                label: tr('Tài khoản riêng tư', 'Private account'),
                subtitle: tr(
                  'Chỉ người theo dõi được duyệt mới xem được bài của bạn.',
                  'Only approved followers can see your posts.',
                ),
                trailing: AppSwitch(
                  value: isPrivate,
                  onChanged: uid == null
                      ? null
                      : (v) =>
                            ref.read(userRepositoryProvider).setPrivate(uid, v),
                ),
              ),
              const _RowDivider(),
              _SettingRow(
                icon: Icons.speaker_notes_off_outlined,
                label: tr('Từ khoá ẩn', 'Hidden words'),
                subtitle: tr('Lọc bình luận chứa từ khoá.', 'Filter comments.'),
                onTap: () => context.push(Routes.hiddenWords),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          _SectionHeader(
            icon: Icons.shield_outlined,
            title: tr('Bảo mật', 'Security'),
          ),
          _GroupCard(
            children: [
              _SettingRow(
                icon: Icons.lock_reset_rounded,
                label: tr('Đổi mật khẩu', 'Change password'),
                onTap: () => context.push(Routes.changePassword),
              ),
              const _RowDivider(),
              _SettingRow(
                icon: Icons.verified_user_outlined,
                label: tr('Xác thực 2 lớp (2FA)', 'Two-factor (2FA)'),
                onTap: () => context.push(Routes.mfaEnroll),
              ),
              const _RowDivider(),
              _SettingRow(
                icon: Icons.history_rounded,
                label: tr('Lịch sử đăng nhập', 'Login history'),
                onTap: () => context.push(Routes.loginHistory),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          _SectionHeader(
            icon: Icons.tune_rounded,
            title: tr('Ứng dụng', 'App'),
          ),
          _GroupCard(
            children: [
              _SettingRow(
                icon: Icons.language_rounded,
                label: tr('Ngôn ngữ', 'Language'),
                trailing: _LangPill(
                  current: currentLang == AppLang.vi ? 'Tiếng Việt' : 'English',
                ),
                onTap: () => ref.read(localeProvider.notifier).toggle(),
              ),
              const _RowDivider(),
              _SettingRow(
                icon: isDark
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                label: tr('Giao diện', 'Display'),
                subtitle: isDark
                    ? tr('Tối · Nova', 'Dark · Nova')
                    : tr('Sáng · Moment', 'Light · Moment'),
                trailing: AppSwitch(
                  value: isDark,
                  onChanged: (v) => ref
                      .read(displayThemeProvider.notifier)
                      .set(v ? DisplaySkin.dark : DisplaySkin.light),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    // Delegates to the shared AppSectionLabel so section headers stay identical
    // app-wide; keeps only the settings-specific spacing.
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        bottom: AppSpacing.sm,
        top: AppSpacing.sm,
      ),
      child: AppSectionLabel(title, icon: icon),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 56),
      child: Divider(height: 1, thickness: 1, color: AppColors.borderSubtle),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.md, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppType.subhead,
                    fontWeight: AppType.medium,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: AppType.label,
                        height: 1.3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          trailing ??
              (onTap != null
                  ? Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textTertiary,
                    )
                  : const SizedBox.shrink()),
        ],
      ),
    );
    if (onTap == null) return row;
    return PressScale(onTap: onTap, child: row);
  }
}

class _LangPill extends StatelessWidget {
  const _LangPill({required this.current});
  final String current;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.layer3,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            current,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: AppType.label,
              fontWeight: AppType.bold,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.unfold_more_rounded,
            size: AppIconSize.sm,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
