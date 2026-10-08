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

  test('formatDayLong: day, short month, year, weekday', () {
    expect(formatDayLong(const LocalDate(2026, 10, 1)), '1 окт. 2026, Чт');
    expect(formatDayLong(const LocalDate(2026, 9, 30)), '30 сент. 2026, Ср');
    expect(formatDayLong(const LocalDate(2026, 5, 4)), '4 мая 2026, Пн');
  });

  test('formatTripCount uses Russian plural forms', () {
    const cases = {
      0: '0 поездок',
      1: '1 поездка',
      2: '2 поездки',
      4: '4 поездки',
      5: '5 поездок',
      11: '11 поездок',
      12: '12 поездок',
      14: '14 поездок',
      21: '21 поездка',
      22: '22 поездки',
      25: '25 поездок',
      111: '111 поездок',
    };
    cases.forEach((count, expected) {
      expect(formatTripCount(count), expected, reason: '$count');
    });
  });

  test('formatDeduction prefixes a minus sign', () {
    expect(formatDeduction(585), '−585 ₸');
  });

  test('groupThousands', () {
    expect(groupThousands(''), '');
    expect(groupThousands('999'), '999');
    expect(groupThousands('2400'), '2 400');
    expect(groupThousands('1234567'), '1 234 567');
  });
}
