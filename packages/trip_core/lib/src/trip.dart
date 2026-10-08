import 'local_date.dart';
import 'validation.dart';

enum PaymentMethod {
  cash,
  card;

  /// Parses the wire value (`cash` / `card`); null for anything else.
  static PaymentMethod? tryParse(Object? value) => switch (value) {
        'cash' => PaymentMethod.cash,
        'card' => PaymentMethod.card,
        _ => null,
      };
}

/// One trip. [start] and [end] are always held as UTC instants.
class Trip {
  Trip({
    required this.id,
    required DateTime start,
    required DateTime end,
    required this.amount,
    required this.payment,
    required this.commission,
  })  : start = start.toUtc(),
        end = end.toUtc();

  /// Parses JSON with the same rules as [validateTrip].
  /// Throws [FormatException] when the data is invalid.
  factory Trip.fromJson(Map<String, Object?> json) =>
      switch (validateTrip(json)) {
        ValidTrip(:final trip) => trip,
        InvalidTrip(:final errors) =>
          throw FormatException('Invalid trip: $errors'),
      };

  final String id;
  final DateTime start;
  final DateTime end;

  /// Fare in whole tenge.
  final int amount;
  final PaymentMethod payment;

  /// Commission in whole tenge.
  final int commission;

  Map<String, Object> toJson(Duration offset) => {
        'id': id,
        'start': formatWithOffset(start, offset),
        'end': formatWithOffset(end, offset),
        'amount': amount,
        'payment': payment.name,
        'commission': commission,
      };

  /// Same id and same data. Instants are compared as moments, so
  /// `08:10+05:00` equals `03:10Z`. Used to tell a replay from a conflict.
  @override
  bool operator ==(Object other) =>
      other is Trip &&
      other.id == id &&
      other.start == start &&
      other.end == end &&
      other.amount == amount &&
      other.payment == payment &&
      other.commission == commission;

  @override
  int get hashCode => Object.hash(id, start, end, amount, payment, commission);

  @override
  String toString() =>
      'Trip($id, $start–$end, $amount ${payment.name}, commission $commission)';
}
