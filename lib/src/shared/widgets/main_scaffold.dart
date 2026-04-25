import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainScaffold extends StatelessWidget {
  const MainScaffold({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _indexFromLocation(location);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.96),
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Row(
          children: [
            _NavItem(
              active: selectedIndex == 0,
              icon: Icons.map_rounded,
              label: 'Map',
              colorScheme: colorScheme,
              onTap: () => context.go('/map'),
            ),
            _NavItem(
              active: selectedIndex == 1,
              icon: Icons.calendar_today_rounded,
              label: 'Schedule',
              colorScheme: colorScheme,
              onTap: () => context.go('/schedule'),
            ),
            _NavItem(
              active: selectedIndex == 2,
              icon: Icons.info_rounded,
              label: 'About',
              colorScheme: colorScheme,
              onTap: () => context.go('/about'),
            ),
            _NavItem(
              active: selectedIndex == 3,
              icon: Icons.settings_rounded,
              label: 'Settings',
              colorScheme: colorScheme,
              onTap: () => context.go('/settings'),
            ),
          ],
        ),
      ),
    );
  }

  int _indexFromLocation(String location) {
    if (location.startsWith('/schedule')) {
      return 1;
    }
    if (location.startsWith('/about')) {
      return 2;
    }
    if (location.startsWith('/settings')) {
      return 3;
    }
    return 0;
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.active,
    required this.icon,
    required this.label,
    required this.colorScheme,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 36,
                decoration: BoxDecoration(
                  color: active ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  icon,
                  color: active ? Colors.white : colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
