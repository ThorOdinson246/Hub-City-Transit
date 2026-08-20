import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/app/providers.dart';
import 'src/core/platform/url_strategy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();

  // Read before the first frame: the router's onboarding redirect runs
  // synchronously, and a deep link arrives with no chance to await.
  final onboardingSeen = await readOnboardingSeen();

  runApp(
    ProviderScope(
      overrides: [
        onboardingSeenProvider.overrideWith((ref) => onboardingSeen),
      ],
      child: const HubCityTransitApp(),
    ),
  );
}
