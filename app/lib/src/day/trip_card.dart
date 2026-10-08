import 'package:flutter/material.dart';
import 'package:trip_core/trip_core.dart';

import '../format.dart';
import '../theme/app_theme.dart';

class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip, required this.offset});

  final Trip trip;
  final Duration offset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatTripTime(trip, offset),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.muted,
                    ),
                  ),
                ),
                PaymentChip(payment: trip.payment),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              formatMoney(trip.amount),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Комиссия: ${formatDeduction(trip.commission)}',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opacity of the payment chip background tint; low enough that the chip
/// text keeps WCAG AA contrast on it in both palettes.
const paymentChipTint = 0.10;

/// «Наличные» (orange) or «Карта» (blue) pill.
class PaymentChip extends StatelessWidget {
  const PaymentChip({super.key, required this.payment});

  final PaymentMethod payment;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isCash = payment == PaymentMethod.cash;
    final color = isCash ? colors.cash : colors.card;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: paymentChipTint),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          isCash ? 'Наличные' : 'Карта',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
