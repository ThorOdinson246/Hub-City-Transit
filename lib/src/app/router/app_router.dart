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
        path: '/location-permission',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LocationPermissionPage()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: OnboardingPage()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: SettingsPage()),
      ),
      GoRoute(
        path: '/about',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: AboutPage()),
      ),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/map',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MapPage()),
          ),
          GoRoute(
            path: '/schedule',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SchedulePage()),
          ),
          GoRoute(
            path: '/fares',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: FaresPage()),
          ),
        ],
      ),
    ],
  );
});
