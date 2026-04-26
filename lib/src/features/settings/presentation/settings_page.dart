import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/constants/route_metadata.dart';
import '../../../core/constants/transit_ids.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final themeMode = ref.watch(themeModeProvider);
    final darkBasemap = ref.watch(darkBasemapProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // Page title
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
            child: Text('Settings', style: tt.headlineLarge),
          ),

          // ── Appearance section ──────────────────────────────────────────────
          _SectionLabel(label: 'Appearance', cs: cs),
          const SizedBox(height: 8),

          _SettingsCard(
            cs: cs,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      color: cs.onSurfaceVariant,
                      size: 22,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Theme', style: tt.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            'Choose light, dark, or follow system',
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
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    _ThemePill(
                      label: 'System',
                      icon: Icons.brightness_auto_rounded,
                      selected: themeMode == ThemeMode.system,
                      cs: cs,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setMode(ThemeMode.system),
                    ),
                    const SizedBox(width: 8),
                    _ThemePill(
                      label: 'Light',
                      icon: Icons.light_mode_rounded,
                      selected: themeMode == ThemeMode.light,
                      cs: cs,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setMode(ThemeMode.light),
                    ),
                    const SizedBox(width: 8),
                    _ThemePill(
                      label: 'Dark',
                      icon: Icons.dark_mode_rounded,
                      selected: themeMode == ThemeMode.dark,
                      cs: cs,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setMode(ThemeMode.dark),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text('Dark Map Tiles', style: tt.titleMedium),
                subtitle: Text(
                  'Use dark map tiles in dark mode',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                value: darkBasemap,
                activeThumbColor: cs.primary,
                onChanged: (val) =>
                    ref.read(darkBasemapProvider.notifier).toggle(val),
                secondary: Icon(
                  Icons.map_outlined,
                  color: cs.onSurfaceVariant,
                  size: 22,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── App section ────────────────────────────────────────────────────
          _SectionLabel(label: 'App', cs: cs),
          const SizedBox(height: 8),

          _SettingsCard(
            cs: cs,
            children: [
              _SettingsTile(
                cs: cs,
                tt: tt,
                icon: Icons.notifications_outlined,
                title: 'Alerts & Notifications',
                subtitle: 'Route changes and delay updates',
                isFirst: true,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notifications coming soon!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _SettingsTile(
                cs: cs,
                tt: tt,
                icon: Icons.location_on_outlined,
                title: 'Location Services',
                subtitle: 'Manage GPS usage and permissions',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Location settings coming soon!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _SettingsTile(
                cs: cs,
                tt: tt,
                icon: Icons.info_outline_rounded,
                title: 'About',
                subtitle: 'Route legend, app info, and support',
                isLast: true,
                onTap: () => context.push('/about'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Fares ──────────────────────────────────────────────────────────
          _SectionLabel(label: 'Fares', cs: cs),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Most rides are 50¢. Reduced and free fares are available for eligible riders with ID.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),

          _FareCard(
            cs: cs,
            tt: tt,
            icon: Icons.credit_card_rounded,
            title: 'Standard fare',
            price: '\$0.50',
            subtitle: 'All riders unless eligible for reduced or free fare.',
          ),
          const SizedBox(height: 12),
          _FareCard(
            cs: cs,
            tt: tt,
            icon: Icons.people_alt_rounded,
            title: 'Reduced fare',
            price: '\$0.25',
            checks: const [
              'Children (ages 5–high school)',
              'Seniors (62+)',
              'Disabled with ID',
              'HCT ID and Medicare',
            ],
          ),
          const SizedBox(height: 12),
          _FareCard(
            cs: cs,
            tt: tt,
            icon: Icons.school_rounded,
            title: 'Free fare',
            price: '\$0.00',
            checks: const ['Southern Miss ID', 'City of Hattiesburg employees'],
          ),
          const SizedBox(height: 12),
          _FareCard(
            cs: cs,
            tt: tt,
            icon: Icons.info_outline_rounded,
            title: 'How to pay',
            price: null,
            checks: const [
              'Have exact change ready',
              'Drivers do not carry change',
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children, required this.cs});
  final List<Widget> children;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.cs,
    required this.tt,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isFirst = false,
    this.isLast = false,
    this.onTap,
  });
  final ColorScheme cs;
  final TextTheme tt;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Icon(icon, color: cs.onSurfaceVariant, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: tt.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
          if (!isLast)
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}

class _FareCard extends StatelessWidget {
  const _FareCard({
    required this.cs,
    required this.tt,
    required this.icon,
    required this.title,
    this.price,
    this.subtitle,
    this.checks,
  });
  final ColorScheme cs;
  final TextTheme tt;
  final IconData icon;
  final String title;
  final String? price;
  final String? subtitle;
  final List<String>? checks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: cs.primary, size: 16),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (price != null) ...[
            const SizedBox(height: 16),
            Text(
              price!,
              style: tt.headlineLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 36,
              ),
            ),
          ],
          if (subtitle != null) ...[
            const SizedBox(height: 12),
            Text(
              subtitle!,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          if (checks != null) ...[
            const SizedBox(height: 16),
            ...checks!.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c,
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThemePill extends StatelessWidget {
  const _ThemePill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.cs,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? cs.primary : cs.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

