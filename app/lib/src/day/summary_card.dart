import 'package:flutter/material.dart';
import 'package:trip_core/trip_core.dart';

import '../format.dart';
import '../theme/app_theme.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: colors.muted);
    final legend = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'НА РУКИ',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.muted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Text(formatTripCount(summary.tripCount), style: muted),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              formatMoney(summary.net),
              style: theme.textTheme.displaySmall?.copyWith(
                color: colors.net,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            Text('Выручка: ${formatMoney(summary.revenue)}', style: muted),
            Text(
              'Комиссия: ${formatDeduction(summary.commission)}',
              style: muted,
            ),
            const SizedBox(height: 16),
            _PaymentSplitBar(
              cash: summary.cash.revenue,
              card: summary.card.revenue,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Наличные: ${formatMoney(summary.cash.revenue)}',
                    style: legend?.copyWith(color: colors.cash),
                  ),
                ),
                Text(
                  'Карта: ${formatMoney(summary.card.revenue)}',
                  style: legend?.copyWith(color: colors.card),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Cash vs card share of the day's revenue; a plain track when there is none.
class _PaymentSplitBar extends StatelessWidget {
  const _PaymentSplitBar({required this.cash, required this.card});

  final int cash;
  final int card;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: cash + card == 0
            ? ColoredBox(color: Theme.of(context).colorScheme.outline)
            : Row(
                children: [
                  if (cash > 0)
                    Expanded(
                      flex: cash,
                      child: ColoredBox(
                        key: const Key('split-cash'),
                        color: colors.cash,
                      ),
                    ),
                  if (cash > 0 && card > 0) const SizedBox(width: 3),
                  if (card > 0)
                    Expanded(
                      flex: card,
                      child: ColoredBox(
                        key: const Key('split-card'),
                        color: colors.card,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
