import 'package:flutter/material.dart';

class FaresPage extends StatelessWidget {
  const FaresPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: const [
          _PageHeader(),
          SizedBox(height: 14),
          _FareCard(
            title: 'Standard fare',
            amount: '4.50',
            note: 'All riders unless eligible for reduced or free fare.',
            icon: Icons.payment_outlined,
          ),
          SizedBox(height: 12),
          _FareCard(
            title: 'Reduced fare',
            amount: '4.25',
            note:
                'Children (ages 5-high school), seniors, disabled with ID, and Medicare card holders.',
            icon: Icons.groups_2_outlined,
          ),
          SizedBox(height: 12),
          _FareCard(
            title: 'Free fare',
            amount: '4.00',
            note: 'Southern Miss ID and City of Hattiesburg employees.',
            icon: Icons.school_outlined,
          ),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fares', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          'Most rides are 50c. Reduced and free fares are available for eligible riders with ID.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _FareCard extends StatelessWidget {
  const _FareCard({
    required this.title,
    required this.amount,
    required this.note,
    required this.icon,
  });

  final String title;
  final String amount;
  final String note;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 24 / 2, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Text(amount, style: const TextStyle(fontSize: 44 / 2, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(note),
        ],
      ),
    );
  }
}
