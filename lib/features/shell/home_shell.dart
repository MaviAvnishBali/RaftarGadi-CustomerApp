import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:localization/localization.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Hosts the four primary tabs inside the adaptive [RaftarNavShell]. The
/// GoRouter [StatefulNavigationShell] preserves each tab's own navigation
/// stack; tapping a tab (or re-tapping the current one to reset it) is wired
/// through [StatefulNavigationShell.goBranch].
class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DoubleBackExitScope(
      onBack: () {
        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
          return true;
        }
        return false;
      },
      child: RaftarNavShell(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        leading: const RaftarLogo(height: 40),
        destinations: [
          RaftarDestination(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: l10n.navHome,
          ),
          RaftarDestination(
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long_rounded,
            label: l10n.navBookings,
          ),
          RaftarDestination(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: l10n.navProfile,
          ),
        ],
        body: navigationShell,
      ),
    );
  }
}
