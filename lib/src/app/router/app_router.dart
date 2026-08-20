import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/responsive.dart';
import '../providers.dart';
import '../../features/about/presentation/about_page.dart';
import '../../features/announcements/presentation/announcements_inbox_page.dart';
import '../../features/launch/presentation/launch_page.dart';
import '../../features/map/presentation/map_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/schedule/presentation/schedule_page.dart';
import '../../features/settings/presentation/settings_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/launch',
    // initialLocation only applies when the platform hands go_router "/". On web any URL is an
    // entry point, so without this guard a first-time visitor arriving at /schedule or a shared
    // /map link skipped onboarding entirely and never saw it again.
    redirect: (context, state) {
      final seen = ref.read(onboardingSeenProvider);
      final target = state.matchedLocation;

      if (!seen) {
        if (target == '/onboarding' || target == '/launch') return null;
        // Remember where they were actually headed. Without this, someone
        // opening a shared /about link for the first time is sent through
        // onboarding and then dumped on /map — the link silently does nothing.
        ref.read(pendingDeepLinkProvider.notifier).state = state.uri.toString();
        return '/onboarding';
      }

      // Onboarding is the only gated route; everything else passes through.
      return target == '/onboarding' ? '/map' : null;
    },
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
        path: '/about',
        pageBuilder: (context, state) => const MaterialPage(child: AboutPage()),
      ),
      GoRoute(
        path: '/announcements',
        pageBuilder: (context, state) =>
            const MaterialPage(child: AnnouncementsInboxPage()),
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
            ],
          ),
        ],
      ),
    ],
  );
});

/// Shell chrome for [StatefulShellRoute].
///
/// Switches between a bottom [NavigationBar] and a side [NavigationRail] at the
/// Material 3 expanded breakpoint. The destinations and their order are
/// identical in both — this is the same navigation, placed where the pointer
/// already is on a wide window, not a different information architecture.
class _StatefulScaffold extends StatelessWidget {
  const _StatefulScaffold({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _destinations = <({IconData icon, IconData selected, String label})>[
    (icon: Icons.map_outlined, selected: Icons.map_rounded, label: 'Map'),
    (
      icon: Icons.calendar_today_outlined,
      selected: Icons.calendar_today_rounded,
      label: 'Schedule',
    ),
    (
      icon: Icons.settings_outlined,
      selected: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  void _onSelected(int index) {
    navigationShell.goBranch(
      index,
      // Go back to initial route if already on this branch
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Breakpoints.of(context).prefersRail) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onSelected,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        animationDuration: const Duration(milliseconds: 300),
        onDestinationSelected: _onSelected,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selected),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
