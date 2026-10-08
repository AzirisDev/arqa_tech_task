import 'trip.dart';

/// Totals for one payment method.
class PaymentBreakdown {
  const PaymentBreakdown({
    required this.count,
    required this.revenue,
    required this.commission,
  });

  factory PaymentBreakdown.fromJson(Map<String, Object?> json) =>
      PaymentBreakdown(
        count: json['count'] as int,
        revenue: json['revenue'] as int,
        commission: json['commission'] as int,
      );

  static const zero = PaymentBreakdown(count: 0, revenue: 0, commission: 0);

  final int count;
  final int revenue;
  final int commission;

  PaymentBreakdown _add(Trip trip) => PaymentBreakdown(
    count: count + 1,
    revenue: revenue + trip.amount,
    commission: commission + trip.commission,
  );

  Map<String, int> toJson() => {
    'count': count,
    'revenue': revenue,
    'commission': commission,
  };

  @override
  bool operator ==(Object other) =>
      other is PaymentBreakdown &&
      other.count == count &&
      other.revenue == revenue &&
      other.commission == commission;

  @override
  int get hashCode => Object.hash(count, revenue, commission);

  @override
  String toString() =>
      'PaymentBreakdown(count: $count, revenue: $revenue, commission: $commission)';
}

/// Totals for one day.
class DaySummary {
  const DaySummary({
    required this.tripCount,
    required this.revenue,
    required this.commission,
    required this.cash,
    required this.card,
  });

  factory DaySummary.fromJson(Map<String, Object?> json) => DaySummary(
    tripCount: json['tripCount'] as int,
    revenue: json['revenue'] as int,
    commission: json['commission'] as int,
    cash: PaymentBreakdown.fromJson(json['cash'] as Map<String, Object?>),
    card: PaymentBreakdown.fromJson(json['card'] as Map<String, Object?>),
  );

  final int tripCount;
  final int revenue;
  final int commission;
  final PaymentBreakdown cash;
  final PaymentBreakdown card;

  /// Take-home («на руки»): revenue minus commission.
  int get net => revenue - commission;

  Map<String, Object> toJson() => {
    'tripCount': tripCount,
    'revenue': revenue,
    'commission': commission,
    'net': net,
    'cash': cash.toJson(),
    'card': card.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is DaySummary &&
      other.tripCount == tripCount &&
      other.revenue == revenue &&
      other.commission == commission &&
      other.cash == cash &&
      other.card == card;

  @override
  int get hashCode => Object.hash(tripCount, revenue, commission, cash, card);

  @override
  String toString() =>
      'DaySummary(trips: $tripCount, revenue: $revenue, '
      'commission: $commission, net: $net, cash: $cash, card: $card)';
}

/// Sums [trips]. The caller passes the trips of one day; no filtering here.
DaySummary summarize(Iterable<Trip> trips) {
  var cash = PaymentBreakdown.zero;
  var card = PaymentBreakdown.zero;
  for (final trip in trips) {
    switch (trip.payment) {
      case PaymentMethod.cash:
        cash = cash._add(trip);
      case PaymentMethod.card:
        card = card._add(trip);
    }
  }
  return DaySummary(
    tripCount: cash.count + card.count,
    revenue: cash.revenue + card.revenue,
    commission: cash.commission + card.commission,
    cash: cash,
    card: card,
  );
}
