import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/about/presentation/about_page.dart';
import '../../features/fares/presentation/fares_page.dart';
import '../../features/launch/presentation/launch_page.dart';
import '../../features/map/presentation/map_page.dart';
import '../../features/onboarding/presentation/location_permission_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/schedule/presentation/schedule_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../shared/widgets/main_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/launch',
    routes: [
      GoRoute(
        path: '/launch',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LaunchPage()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: OnboardingPage()),
      ),
      GoRoute(
        path: '/location-permission',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LocationPermissionPage()),
      ),
      GoRoute(
        path: '/about',
        pageBuilder: (context, state) => const MaterialPage(child: AboutPage()),
      ),
      // StatefulShellRoute keeps each branch widget alive in an IndexedStack,
      // so the MapPage camera position, selected stop, and bus info panel are
      // preserved when the user navigates to Schedule or Settings and back.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _StatefulScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: MapPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/schedule',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: SchedulePage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: SettingsPage()),
              ),
              GoRoute(
                path: '/fares',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: FaresPage()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Scaffold wrapper for StatefulShellRoute that uses the NavigationBar
/// from MainScaffold to switch between branches without rebuilding.
class _StatefulScaffold extends StatelessWidget {
  const _StatefulScaffold({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        animationDuration: const Duration(milliseconds: 300),
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            // Go back to initial route if already on this branch
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today_rounded),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
