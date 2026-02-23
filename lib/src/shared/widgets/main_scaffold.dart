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
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/map');
              break;
            case 1:
              context.go('/schedule');
              break;
            case 2:
              context.go('/about');
              break;
            default:
              context.go('/map');
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            label: 'Schedule',
          ),
          NavigationDestination(icon: Icon(Icons.info_outline), label: 'About'),
        ],
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
