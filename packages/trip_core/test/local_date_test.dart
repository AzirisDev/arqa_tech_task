import 'package:test/test.dart';
import 'package:trip_core/trip_core.dart';

const plus5 = Duration(hours: 5);

void main() {
  group('LocalDate.of', () {
    test('early-morning local time stays on the same local day', () {
      // 00:30 at +05:00 is 19:30Z of the previous UTC day.
      final instant = DateTime.parse('2026-10-02T00:30:00+05:00');
      expect(LocalDate.of(instant, plus5), const LocalDate(2026, 10, 2));
    });

    test('UTC input is converted into the driver offset', () {
      // 20:00Z is 01:00 next day at +05:00.
      final instant = DateTime.parse('2026-10-01T20:00:00Z');
      expect(LocalDate.of(instant, plus5), const LocalDate(2026, 10, 2));
    });

    test('late-evening local time stays on its day', () {
      final instant = DateTime.parse('2026-10-02T23:40:00+05:00');
      expect(LocalDate.of(instant, plus5), const LocalDate(2026, 10, 2));
    });
  });

  group('LocalDate.tryParse', () {
    test('parses YYYY-MM-DD and round-trips through toString', () {
      final date = LocalDate.tryParse('2026-10-01');
      expect(date, const LocalDate(2026, 10, 1));
      expect(date.toString(), '2026-10-01');
    });

    test('rejects malformed and impossible dates', () {
      for (final input in [
        '2026-1-01',
        '01.10.2026',
        '2026-02-30',
        '2026-13-01',
        '',
      ]) {
        expect(LocalDate.tryParse(input), isNull, reason: input);
      }
    });
  });

  test('addDays crosses month and year boundaries', () {
    expect(
      const LocalDate(2026, 10, 31).addDays(1),
      const LocalDate(2026, 11, 1),
    );
    expect(
      const LocalDate(2027, 1, 1).addDays(-1),
      const LocalDate(2026, 12, 31),
    );
  });

  test('weekday is ISO (2026-10-01 is a Thursday)', () {
    expect(const LocalDate(2026, 10, 1).weekday, DateTime.thursday);
  });

  test('compareTo orders chronologically', () {
    final dates = [
      const LocalDate(2026, 10, 2),
      const LocalDate(2025, 12, 31),
      const LocalDate(2026, 9, 30),
    ]..sort();
    expect(dates.map((d) => d.toString()), [
      '2025-12-31',
      '2026-09-30',
      '2026-10-02',
    ]);
  });

  group('UTC offsets', () {
    test('parse and format', () {
      const minus330 = Duration(hours: -3, minutes: -30);
      expect(parseUtcOffset('+05:00'), plus5);
      expect(parseUtcOffset('-03:30'), minus330);
      expect(formatUtcOffset(plus5), '+05:00');
      expect(formatUtcOffset(minus330), '-03:30');
      expect(formatUtcOffset(Duration.zero), '+00:00');
      expect(() => parseUtcOffset('5'), throwsFormatException);
    });

    test('formatWithOffset renders the instant in driver time', () {
      final instant = DateTime.parse('2026-10-01T03:10:00Z');
      expect(formatWithOffset(instant, plus5), '2026-10-01T08:10:00+05:00');
    });
  });
}
