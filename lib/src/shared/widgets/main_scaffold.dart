import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Main scaffold with bottom navigation bar.
/// Uses an [IndexedStack] (via [PageStorage]) to preserve state
/// across tab switches — the [MapPage] keeps its camera position,
/// selected stop, and bus info panel even after switching to Schedule/Settings.
class MainScaffold extends StatefulWidget {
  const MainScaffold({required this.child, super.key});
  final Widget child;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _indexFromLocation(location);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        animationDuration: const Duration(milliseconds: 300),
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/map');
            case 1:
              context.go('/schedule');
            case 2:
              context.go('/settings');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today_rounded),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  int _indexFromLocation(String location) {
    if (location.startsWith('/schedule')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0;
  }
}
