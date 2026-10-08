import 'trip.dart';

sealed class TripValidationResult {
  const TripValidationResult();
}

final class ValidTrip extends TripValidationResult {
  const ValidTrip(this.trip);
  final Trip trip;
}

final class InvalidTrip extends TripValidationResult {
  const InvalidTrip(this.errors);

  /// Field name → message in Russian, shown to the driver as-is.
  final Map<String, String> errors;
}

const maxIdLength = 64;

final _isoWithOffset = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.\d{1,6})?)?'
  r'(?:Z|[+-](\d{2}):(\d{2}))$',
);

/// Parses an ISO-8601 timestamp that carries an explicit offset or `Z`.
///
/// Fractional seconds are accepted but truncated. The offset must be within
/// +-14:59.
///
/// Returns null for anything else: strings without an offset (which
/// `DateTime.parse` would silently read as device-local time) and impossible
/// values like `2026-02-30` or `25:00` (which `DateTime.parse` would roll over).
DateTime? parseInstant(Object? value) {
  if (value is! String) return null;
  final match = _isoWithOffset.firstMatch(value);
  if (match == null) return null;
  final offsetHours = int.tryParse(match[7] ?? '0')!;
  final offsetMinutes = int.tryParse(match[8] ?? '0')!;
  if (offsetHours > 14 || offsetMinutes > 59) return null;
  final fields = [for (var i = 1; i <= 6; i++) int.parse(match[i] ?? '0')];
  final wall = DateTime.utc(
      fields[0], fields[1], fields[2], fields[3], fields[4], fields[5]);
  final normalized = [
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
  ];
  for (var i = 0; i < fields.length; i++) {
    if (fields[i] != normalized[i]) return null;
  }
  final instant = DateTime.parse(value).toUtc();
  // Canonical precision is whole seconds: what we store is what we echo.
  return DateTime.utc(instant.year, instant.month, instant.day, instant.hour,
      instant.minute, instant.second);
}

/// Validates trip JSON. Collects every error, not only the first.
/// Unknown fields are ignored.
TripValidationResult validateTrip(Map<String, Object?> json) {
  final errors = <String, String>{};

  final id = json['id'];
  if (id is! String || id.trim().isEmpty) {
    errors['id'] = 'Не указан id поездки';
  } else if (id.length > maxIdLength) {
    errors['id'] = 'id не может быть длиннее $maxIdLength символов';
  }

  final start = parseInstant(json['start']);
  if (start == null) errors['start'] = 'Некорректное время начала';

  final end = parseInstant(json['end']);
  if (end == null) {
    errors['end'] = 'Некорректное время окончания';
  } else if (start != null && !end.isAfter(start)) {
    errors['end'] = 'Окончание должно быть позже начала';
  }

  final amount = json['amount'];
  if (amount is! int) {
    errors['amount'] = 'Сумма должна быть целым числом';
  } else if (amount <= 0) {
    errors['amount'] = 'Сумма должна быть больше 0';
  }

  final commission = json['commission'];
  if (commission is! int) {
    errors['commission'] = 'Комиссия должна быть целым числом';
  } else if (commission < 0) {
    errors['commission'] = 'Комиссия не может быть отрицательной';
  } else if (amount is int && amount > 0 && commission > amount) {
    errors['commission'] = 'Комиссия не может превышать сумму';
  }

  final payment = PaymentMethod.tryParse(json['payment']);
  if (payment == null) {
    errors['payment'] = 'Выберите способ оплаты: наличные или карта';
  }

  if (errors.isNotEmpty) return InvalidTrip(errors);
  return ValidTrip(Trip(
    id: id as String,
    start: start!,
    end: end!,
    amount: amount as int,
    payment: payment!,
    commission: commission as int,
  ));
}
