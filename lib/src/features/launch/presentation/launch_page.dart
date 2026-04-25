import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LaunchPage extends StatefulWidget {
  const LaunchPage({super.key});

  @override
  State<LaunchPage> createState() => _LaunchPageState();
}

class _LaunchPageState extends State<LaunchPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2200), _routeNext);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _routeNext() async {
    if (!mounted) return;

    // Check if onboarding has been seen
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_seen') ?? false;
    if (!mounted) return;

    if (!seen) {
      context.go('/onboarding');
      return;
    }

    final permission = await Geolocator.checkPermission();
    if (!mounted) return;

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      context.go('/map');
    } else {
      context.go('/map'); // go straight to map; location FAB handles permission
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.04,
              child: CustomPaint(painter: _DotPatternPainter(cs.onSurface)),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                          width: 90,
                          height: 90,
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
                            size: 28,
                            color: cs.onPrimary,
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Hub City\nTransit',
                      textAlign: TextAlign.center,
                      style: tt.displayMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Connecting the city, efficiently.',
                      style: tt.bodyLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 48),
                    Text(
                      'INITIALIZING SYSTEM...',
                      style: tt.labelMedium?.copyWith(letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: 180,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 5,
                          backgroundColor: cs.outlineVariant,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'v2.4.0 (Build 891)',
                      style: tt.bodySmall,
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

class _DotPatternPainter extends CustomPainter {
  _DotPatternPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const spacing = 28.0;
    for (double y = 6; y < size.height; y += spacing) {
      for (double x = 6; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotPatternPainter old) => old.color != color;
}
