import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/route_metadata.dart';
import '../../../core/constants/transit_ids.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Hero
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.directions_bus_rounded,
                    color: cs.onPrimary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hub City Transit', style: tt.titleLarge),
                      Text(
                        'v2.4.0 (Build 891)',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            'Providing reliable, accessible, and efficient public transportation services to the greater Hattiesburg metropolitan area. We connect communities and empower riders every single day.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),

          const SizedBox(height: 24),

          // Route Legend
          Text('Route Legend', style: tt.titleLarge),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: RouteId.values.asMap().entries.map((entry) {
                final i = entry.key;
                final route = entry.value;
                final color = routeColors[route]!;
                final name = routeNames[route]!;
                final desc = routeDescriptions[route]!;
                final isLast = i == RouteId.values.length - 1;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: color.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              Icons.directions_bus_rounded,
                              color: color,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: tt.titleMedium,
                                ),
                                Text(
                                  desc,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Divider(
                        height: 1,
                        indent: 64,
                        color: cs.outlineVariant.withValues(alpha: 0.5),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // App Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Application Info', style: tt.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Live transit data is sourced from the Hub City Open Data Portal and regional transit authority APIs. Schedule times are based on official HCT timetables with GPS-based live adjustments.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(
                          'mailto:support@hubcitytransit.com?subject=App%20Support');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                    icon: const Icon(Icons.support_agent_rounded),
                    label: const Text('Contact Support'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
