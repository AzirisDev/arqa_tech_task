import 'package:trip_core/trip_core.dart';

const _weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
const _months = [
  'янв',
  'фев',
  'мар',
  'апр',
  'мая',
  'июн',
  'июл',
  'авг',
  'сен',
  'окт',
  'ноя',
  'дек',
];
const _nbsp = ' ';

/// `2 400 ₸` with non-breaking spaces, so an amount never wraps.
String formatMoney(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer(amount < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(_nbsp);
    buffer.write(digits[i]);
  }
  return '$buffer$_nbsp₸';
}

/// `чт, 1 окт`
String formatDay(LocalDate date) =>
    '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}';

/// `08:10` in driver time.
String formatClock(DateTime instant, Duration offset) {
  final wall = instant.toUtc().add(offset);
  return '${_two(wall.hour)}:${_two(wall.minute)}';
}

/// `22 мин`, `1 ч 35 мин`
String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 60) return '$minutes мин';
  return '${minutes ~/ 60} ч ${_two(minutes % 60)} мин';
}

/// `08:10–08:32 · 22 мин`; `(+1)` marks a trip that ends the next day.
String formatTripTime(Trip trip, Duration offset) {
  final endsNextDay =
      LocalDate.of(trip.end, offset) != LocalDate.of(trip.start, offset);
  final range =
      '${formatClock(trip.start, offset)}–'
      '${formatClock(trip.end, offset)}${endsNextDay ? ' (+1)' : ''}';
  return '$range · ${formatDuration(trip.end.difference(trip.start))}';
}

String _two(int value) => value.toString().padLeft(2, '0');
