import 'package:trip_core/trip_core.dart';

const _weekdaysTitle = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const _monthsShort = [
  'янв.',
  'февр.',
  'мар.',
  'апр.',
  'мая',
  'июн.',
  'июл.',
  'авг.',
  'сент.',
  'окт.',
  'нояб.',
  'дек.',
];
const _nbsp = ' ';

/// Groups digits by thousands with non-breaking spaces: `2 400`.
String groupThousands(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(_nbsp);
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// `2 400 ₸` with non-breaking spaces, so an amount never wraps.
String formatMoney(int amount) =>
    '${amount < 0 ? '-' : ''}${groupThousands(amount.abs().toString())}$_nbsp₸';

/// `−585 ₸` — an amount taken away, such as commission.
String formatDeduction(int amount) => '−${formatMoney(amount)}';

/// `1 окт. 2026, Чт`
String formatDayLong(LocalDate date) =>
    '${date.day} ${_monthsShort[date.month - 1]} ${date.year}, '
    '${_weekdaysTitle[date.weekday - 1]}';

/// `1 поездка`, `2 поездки`, `5 поездок`.
String formatTripCount(int count) {
  final lastTwo = count % 100;
  final last = count % 10;
  final word = last == 1 && lastTwo != 11
      ? 'поездка'
      : last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14)
      ? 'поездки'
      : 'поездок';
  return '$count $word';
}

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
