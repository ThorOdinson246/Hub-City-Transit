import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/about/presentation/about_page.dart';
import '../../features/map/presentation/map_page.dart';
import '../../features/schedule/presentation/schedule_page.dart';
import '../../shared/widgets/main_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/map',
    routes: [
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
            path: '/about',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AboutPage()),
          ),
        ],
      ),
    ],
  );
});
