import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/constants/route_metadata.dart';
import '../../../core/constants/transit_ids.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;
  static const _total = 3;

  Future<void> _next() async {
    if (_page < _total - 1) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    } else {
      await markOnboardingSeen();
      if (!mounted) return;
      context.go('/map');
    }
  }

  Future<void> _skip() async {
    await markOnboardingSeen();
    if (!mounted) return;
    context.go('/map');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            physics: const ClampingScrollPhysics(),
            children: [
              _WelcomePage(tt: tt, cs: cs),
              _FeaturesPage(tt: tt, cs: cs),
              _LocationPage(tt: tt, cs: cs, onContinue: _next),
            ],
          ),

          // Skip button
          if (_page < _total - 1)
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 16, 0),
                  child: TextButton(
                    onPressed: _skip,
                    child: Text(
                      'Skip',
                      style: tt.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Dots + button
          if (_page < _total - 1)
            Positioned(
              left: 24,
              right: 24,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    children: [
                      // Dot indicators
                      Row(
                        children: List.generate(_total - 1, (i) {
                          final active = i == _page;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(right: 6),
                            width: active ? 22 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: active
                                  ? cs.primary
                                  : cs.outlineVariant,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          );
                        }),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _next,
                        child: const Row(
                          children: [
                            Text('Next'),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Page 1: Welcome ──────────────────────────────────────────────────────────
class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.tt, required this.cs});
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.12),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cs.outlineVariant,
                      width: 3,
                    ),
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_bus_rounded,
                    color: cs.onPrimary,
                    size: 28,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 32),
            Text(
              'Hub City Transit',
              textAlign: TextAlign.center,
              style: tt.headlineLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Your real-time guide to Hattiesburg\'s bus network.',
              textAlign: TextAlign.center,
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            // Route color row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: RouteId.values.map((r) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: routeColors[r]!.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: routeColors[r]!.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: routeColors[r],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        routeNames[r]!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: routeColors[r],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}

// ── Page 2: Features ──────────────────────────────────────────────────────────
class _FeaturesPage extends StatelessWidget {
  const _FeaturesPage({required this.tt, required this.cs});
  final TextTheme tt;
  final ColorScheme cs;

  static const _features = [
    (Icons.gps_fixed_rounded, 'Live Bus Tracking',
        'See exactly where your bus is, updated every 3 seconds.'),
    (Icons.schedule_rounded, 'Real-time Schedules',
        'GPS-adjusted arrival times so you never miss your bus.'),
    (Icons.route_rounded, 'Plan Your Trip',
        'Walk-to-stop + bus directions, right in the app.'),
    (Icons.transfer_within_a_station_rounded, 'Transfer Points',
        'See where routes connect and switch seamlessly.'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What you get', style: tt.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Everything you need to ride Hub City Transit.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            ..._features.map((f) => _FeatureRow(
                  icon: f.$1,
                  title: f.$2,
                  subtitle: f.$3,
                  cs: cs,
                  tt: tt,
                )),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cs,
    required this.tt,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: cs.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page 3: Location ─────────────────────────────────────────────────────────
class _LocationPage extends StatelessWidget {
  const _LocationPage({
    required this.tt,
    required this.cs,
    required this.onContinue,
  });
  final TextTheme tt;
  final ColorScheme cs;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
        child: Column(
          children: [
            const Spacer(),
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.my_location_rounded,
                    color: cs.onPrimary,
                    size: 28,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 32),
            Text(
              'Find your bus faster',
              style: tt.headlineLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Enable location to see nearby stops, walking distances, and accurate arrival times.',
              textAlign: TextAlign.center,
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onContinue,
                child: const Text('Enable Location & Continue'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await markOnboardingSeen();
                if (!context.mounted) return;
                context.go('/map');
              },
              child: const Text('Continue without location'),
            ),
          ],
        ),
      ),
    );
  }
}
