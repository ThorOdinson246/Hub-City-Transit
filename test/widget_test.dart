// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hubcity_transit_flutter/src/app/app.dart';
import 'package:hubcity_transit_flutter/src/app/providers.dart';

void main() {
  testWidgets('App shell renders navigation destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routesProvider.overrideWith((ref) async => []),
          stopsBySelectedRouteProvider.overrideWith((ref) async => []),
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
    expect(find.text('About'), findsWidgets);
  });
}
