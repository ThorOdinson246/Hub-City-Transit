import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class AnalyticsService {
  void logEvent(String name, [Map<String, dynamic>? parameters]);
  void logScreenView(String screenName);
}

class ConsoleAnalyticsService implements AnalyticsService {
  @override
  void logEvent(String name, [Map<String, dynamic>? parameters]) {
    if (!kReleaseMode) {
      debugPrint('[Analytics Event] $name : $parameters');
    }
  }

  @override
  void logScreenView(String screenName) {
    if (!kReleaseMode) {
      debugPrint('[Analytics Screen] $screenName');
    }
  }
}

final analyticsProvider = Provider<AnalyticsService>((ref) {
  // Swap with FirebaseAnalyticsService or PostHogAnalyticsService in the future
  return ConsoleAnalyticsService();
});
