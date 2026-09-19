import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';

/// Custom soft text field ("Moment" style): a rounded pink-tinted fill with a
/// borderless resting state and a pink focus ring. Own label above the field.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.suffix,
    this.validator,
    this.maxLines = 1,
    this.autofillHints,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final int maxLines;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;

  OutlineInputBorder _border(Color c, double w) => OutlineInputBorder(
    borderRadius: AppRadius.brLg,
    borderSide: BorderSide(color: c, width: w),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            bottom: AppSpacing.xs,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppType.label,
              fontWeight: AppType.medium,
              letterSpacing: 0.3,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          maxLines: maxLines,
          autofillHints: autofillHints,
          onChanged: onChanged,
          cursorColor: AppColors.primary,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppType.subhead,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.layer3,
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textTertiary),
            prefixIcon: icon == null
                ? null
                : Icon(
                    icon,
                    size: AppIconSize.md,
                    color: AppColors.textSecondary,
                  ),
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            enabledBorder: _border(Colors.transparent, 0),
            focusedBorder: _border(AppColors.primary, 1.5),
            errorBorder: _border(AppColors.danger, 1),
            focusedErrorBorder: _border(AppColors.danger, 1.5),
          ),
        ),
      ],
    );
  }
}
