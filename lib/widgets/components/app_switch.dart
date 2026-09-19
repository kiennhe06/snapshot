import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';

/// Custom pill toggle (replaces Material Switch): a soft track that fills with
/// the brand gradient when on, and a sliding white knob with a gentle shadow.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.standard,
        width: 50,
        height: 30,
        padding: const EdgeInsets.all(3),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          gradient: value
              ? LinearGradient(
                  colors: [AppColors.primaryBright, AppColors.primary],
                )
              : null,
          color: value ? null : AppColors.borderStrong,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: AppShadows.soft,
          ),
        ),
      ),
    );
  }
}
