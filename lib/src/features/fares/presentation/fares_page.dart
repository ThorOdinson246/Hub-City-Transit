import 'package:flutter/material.dart';

/// Stub fares page — kept for router compatibility.
/// Full fares feature is accessible via hubcitytransit.com.
class FaresPage extends StatelessWidget {
  const FaresPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.attach_money_rounded,
              size: 56,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('Fares', style: tt.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Fare information is available at hubcitytransit.com',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
