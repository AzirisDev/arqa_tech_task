import 'package:flutter/material.dart';
import 'package:trip_core/trip_core.dart';

import '../format.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('На руки', style: theme.textTheme.labelLarge),
            Text(
              formatMoney(summary.net),
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _Stat(
                        label: 'Поездки', value: '${summary.tripCount}')),
                Expanded(
                    child: _Stat(
                        label: 'Выручка',
                        value: formatMoney(summary.revenue))),
                Expanded(
                    child: _Stat(
                        label: 'Комиссия',
                        value: formatMoney(summary.commission))),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _PaymentStat(
                    icon: Icons.payments_outlined,
                    label: 'Наличные',
                    breakdown: summary.cash,
                  ),
                ),
                Expanded(
                  child: _PaymentStat(
                    icon: Icons.credit_card,
                    label: 'Карта',
                    breakdown: summary.card,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

class _PaymentStat extends StatelessWidget {
  const _PaymentStat({
    required this.icon,
    required this.label,
    required this.breakdown,
  });

  final IconData icon;
  final String label;
  final PaymentBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            Text('${breakdown.count} · ${formatMoney(breakdown.revenue)}'),
          ],
        ),
      ],
    );
  }
}
