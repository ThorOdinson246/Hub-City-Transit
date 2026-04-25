import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainScaffold extends StatelessWidget {
  const MainScaffold({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _indexFromLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF4F4F8),
          border: Border(top: BorderSide(color: Color(0x14000000))),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            _NavItem(
              active: selectedIndex == 0,
              icon: Icons.map_rounded,
              label: 'Map',
              onTap: () => context.go('/map'),
            ),
            _NavItem(
              active: selectedIndex == 1,
              icon: Icons.calendar_today_rounded,
              label: 'Schedule',
              onTap: () => context.go('/schedule'),
            ),
            _NavItem(
              active: selectedIndex == 2,
              icon: Icons.info_rounded,
              label: 'About',
              onTap: () => context.go('/about'),
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
    return 0;
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: active ? Colors.black : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: active ? Colors.white : const Color(0xFF6B7280),
                  size: 20,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? Colors.black : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
