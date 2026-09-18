import 'package:flutter/material.dart';

import 'package:snapshot/app/theme.dart';
import 'package:snapshot/core/design/tokens.dart';
import 'package:snapshot/widgets/components/components.dart';

/// Shown briefly while the auth state resolves. The router redirects away once
/// [authStateProvider] emits.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_rounded,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Snapshot',
              textAlign: TextAlign.center,
              style: brandWordmark(context, size: 40),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
