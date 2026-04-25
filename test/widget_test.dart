// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hubcity_transit_flutter/src/app/app.dart';
import 'package:hubcity_transit_flutter/src/app/router/app_router.dart';
import 'package:hubcity_transit_flutter/src/app/providers.dart';
import 'package:hubcity_transit_flutter/src/shared/widgets/main_scaffold.dart';

void main() {
  testWidgets('App shell renders navigation destinations', (
    WidgetTester tester,
  ) async {
    final testRouter = GoRouter(
      initialLocation: '/map',
      routes: [
        ShellRoute(
          builder: (context, state, child) => MainScaffold(child: child),
          routes: [
            GoRoute(
              path: '/map',
              pageBuilder: (context, state) =>
              NoTransitionPage(child: const SizedBox.shrink()),
            ),
            GoRoute(
              path: '/schedule',
              pageBuilder: (context, state) =>
              NoTransitionPage(child: const SizedBox.shrink()),
            ),
            GoRoute(
              path: '/fares',
              pageBuilder: (context, state) =>
              NoTransitionPage(child: const SizedBox.shrink()),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRouterProvider.overrideWithValue(testRouter),
          routesProvider.overrideWith((ref) async => []),
          stopsBySelectedRouteProvider.overrideWith((ref) async => []),
          allStopsByRouteProvider.overrideWith((ref) async => const {}),
          busLocationPollingProvider.overrideWith(
            (ref) => const Stream<Never>.empty(),
          ),
        ],
        child: const HubCityTransitApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Map'), findsWidgets);
    expect(find.text('Schedule'), findsWidgets);
    expect(find.text('Fares'), findsWidgets);
  });
}
