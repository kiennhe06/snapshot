import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../widgets/components/app_bottom_nav.dart';
import '../../explore/presentation/explore_screen.dart';
import '../../feed/presentation/feed_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../reels/presentation/reels_feed_screen.dart';
import '../../reels/providers/reels_providers.dart';

/// Main shell with the custom bottom navigation (no Material NavigationBar).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  List<AppNavItem> get _items => [
    AppNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: tr('Trang chủ', 'Home'),
    ),
    AppNavItem(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore_rounded,
      label: tr('Khám phá', 'Explore'),
    ),
    AppNavItem(
      icon: Icons.movie_outlined,
      activeIcon: Icons.movie_rounded,
      label: 'Reels',
    ),
    AppNavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: tr('Cá nhân', 'You'),
    ),
  ];

  static const int _reelsIndex = 2;

  @override
  Widget build(BuildContext context) {
    // On the Reels tab the video plays full-screen: the nav hides unless the
    // viewer taps to reveal it.
    final reelsChrome = ref.watch(reelsChromeProvider);
    final hideNav = _index == _reelsIndex && !reelsChrome;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      // IndexedStack keeps each tab's state; the custom bottom nav animates.
      body: IndexedStack(
        index: _index,
        children: const [
          FeedScreen(),
          ExploreScreen(),
          ReelsFeedScreen(),
          ProfileScreen(),
        ],
      ),
      // Slide the nav out of view for immersive Reels, keep it reserved for
      // every other tab. AnimatedSwitcher gives it a soft slide.
      bottomNavigationBar: AnimatedSwitcher(
        duration: AppMotion.base,
        switchInCurve: AppMotion.emphasized,
        switchOutCurve: AppMotion.standard,
        transitionBuilder: (child, anim) => SizeTransition(
          sizeFactor: anim,
          alignment: Alignment.topCenter,
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: hideNav
            ? const SizedBox.shrink()
            : AppBottomNav(
                items: _items,
                currentIndex: _index,
                onTap: (i) {
                  if (i != _index) HapticFeedback.selectionClick();
                  // Entering Reels starts immersive (nav hidden).
                  if (i == _reelsIndex) {
                    ref.read(reelsChromeProvider.notifier).hide();
                  }
                  setState(() => _index = i);
                },
                onCreate: () => context.push(Routes.createPost),
                createLabel: tr('Đăng bài', 'Post'),
              ),
      ),
    );
  }
}
