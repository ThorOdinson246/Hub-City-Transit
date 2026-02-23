import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            'About Hub City Transit',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 12),
          Text(
            'This Android-first Flutter app is a migration of the production Next.js transit tracker, preserving route, stop, ETA, and live bus behavior while adopting modular, null-safe Dart architecture.',
          ),
          SizedBox(height: 16),
          Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Tech stack: Flutter, Riverpod, Dio, Freezed, go_router, flutter_map.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
