import 'package:flutter/material.dart';
import 'package:trip_core/trip_core.dart';

import '../format.dart';

class TripTile extends StatelessWidget {
  const TripTile({super.key, required this.trip, required this.offset});

  final Trip trip;
  final Duration offset;

  @override
  Widget build(BuildContext context) {
    final isCash = trip.payment == PaymentMethod.cash;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isCash ? Icons.payments_outlined : Icons.credit_card,
        semanticLabel: isCash ? 'Наличные' : 'Карта',
      ),
      title: Text(formatTripTime(trip, offset)),
      subtitle: Text('Комиссия ${formatMoney(trip.commission)}'),
      trailing: Text(
        formatMoney(trip.amount),
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
