import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/i18n.dart';
import '../../../widgets/components/app_bottom_nav.dart';
import '../../explore/presentation/explore_screen.dart';
import '../../feed/presentation/feed_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../reels/presentation/reels_feed_screen.dart';

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
      icon: Icons.movie_outlined,
      activeIcon: Icons.movie_rounded,
      label: 'Reels',
    ),
    AppNavItem(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore_rounded,
      label: tr('Khám phá', 'Explore'),
    ),
    AppNavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: tr('Hồ sơ', 'Profile'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      // IndexedStack keeps each tab's state; the custom bottom nav animates.
      body: IndexedStack(
        index: _index,
        children: const [
          FeedScreen(),
          ReelsFeedScreen(),
          ExploreScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        items: _items,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
