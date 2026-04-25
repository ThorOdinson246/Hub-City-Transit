import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

class LocationPermissionPage extends StatefulWidget {
  const LocationPermissionPage({super.key});
  @override
  State<LocationPermissionPage> createState() => _LocationPermissionPageState();
}

class _LocationPermissionPageState extends State<LocationPermissionPage> {
  String? _error;
  bool _requesting = false;

  Future<void> _enable() async {
    if (_requesting) return;
    setState(() { _requesting = true; _error = null; });

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      if (!mounted) return;
      setState(() { _requesting = false; _error = 'Location services are disabled on this device.'; });
      return;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (!mounted) return;

    if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
      context.go('/map');
    } else {
      setState(() { _requesting = false; _error = 'Permission not granted. You can enable it later in Settings.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(children: [
        Positioned(top: -80, right: -80,
          child: Container(width: 260, height: 260,
            decoration: BoxDecoration(
              color: const Color(0xFF77B7FF).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            )),
        ),
        SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(children: [
            const Spacer(),
            SizedBox(width: 200, height: 200, child: Stack(alignment: Alignment.center, children: [
              Container(width: 180, height: 180, decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
              )),
              Container(width: 140, height: 140, decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
              )),
              Container(width: 100, height: 100, decoration: BoxDecoration(
                color: cs.surfaceContainerLow, shape: BoxShape.circle)),
              Container(width: 60, height: 60, decoration: BoxDecoration(
                color: cs.primary, shape: BoxShape.circle),
                child: Icon(Icons.my_location_rounded, color: cs.onPrimary, size: 28)),
            ])),
            const SizedBox(height: 32),
            Text('Find your bus faster', style: tt.headlineLarge, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text('Enable location to see the nearest stops and get accurate arrival times.',
              textAlign: TextAlign.center,
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!, textAlign: TextAlign.center,
                  style: tt.bodySmall?.copyWith(color: cs.error)),
              ),
            ],
            const Spacer(),
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: _requesting ? null : _enable,
              child: Text(_requesting ? 'Enabling...' : 'Enable Location'),
            )),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/map'),
              child: const Text('Continue without location'),
            ),
          ]),
        )),
      ]),
    );
  }
}
