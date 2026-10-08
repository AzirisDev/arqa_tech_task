import 'package:flutter_test/flutter_test.dart';
import 'package:shift_diary/src/format.dart';
import 'package:trip_core/trip_core.dart';

import 'fakes.dart';

void main() {
  test('formatMoney groups thousands with non-breaking spaces', () {
    expect(formatMoney(0), '0 ₸');
    expect(formatMoney(999), '999 ₸');
    expect(formatMoney(2400), '2 400 ₸');
    expect(formatMoney(1234567), '1 234 567 ₸');
  });

  test('formatDay uses short Russian weekday and month', () {
    expect(formatDay(const LocalDate(2026, 10, 1)), 'чт, 1 окт');
    expect(formatDay(const LocalDate(2026, 9, 30)), 'ср, 30 сен');
    expect(formatDay(const LocalDate(2026, 5, 4)), 'пн, 4 мая');
  });

  test('formatDuration', () {
    expect(formatDuration(const Duration(minutes: 22)), '22 мин');
    expect(formatDuration(const Duration(minutes: 95)), '1 ч 35 мин');
    expect(formatDuration(const Duration(minutes: 60)), '1 ч 00 мин');
  });

  test('formatTripTime shows driver-local range and duration', () {
    expect(formatTripTime(sampleTrips().first, plus5), '08:10–08:32 · 22 мин');
  });

  test('formatTripTime marks trips that end on the next day', () {
    final late = tripAt(
      't8',
      '2026-10-02T23:40:00+05:00',
      '2026-10-03T00:15:00+05:00',
      3500,
      PaymentMethod.card,
      525,
    );
    expect(formatTripTime(late, plus5), '23:40–00:15 (+1) · 35 мин');
  });
}
