import 'package:trip_core/trip_core.dart';

const plus5 = Duration(hours: 5);

/// Assignment sample trip `t1`; override any field.
Trip sampleTrip({
  String id = 't1',
  String start = '2026-10-01T08:10:00+05:00',
  String end = '2026-10-01T08:32:00+05:00',
  int amount = 2400,
  PaymentMethod payment = PaymentMethod.card,
  int commission = 360,
}) => Trip(
  id: id,
  start: DateTime.parse(start),
  end: DateTime.parse(end),
  amount: amount,
  payment: payment,
  commission: commission,
);
