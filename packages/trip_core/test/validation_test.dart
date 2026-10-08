import 'dart:convert';

import 'package:test/test.dart';
import 'package:trip_core/trip_core.dart';

const plus5 = Duration(hours: 5);

Map<String, Object?> sample() => {
      'id': 't1',
      'start': '2026-10-01T08:10:00+05:00',
      'end': '2026-10-01T08:32:00+05:00',
      'amount': 2400,
      'payment': 'card',
      'commission': 360,
    };

Map<String, String> errorsOf(Map<String, Object?> json) =>
    switch (validateTrip(json)) {
      InvalidTrip(:final errors) => errors,
      ValidTrip() => const {},
    };

void main() {
  test('accepts the assignment sample', () {
    final result = validateTrip(sample());
    expect(result, isA<ValidTrip>());
    final trip = (result as ValidTrip).trip;
    expect(trip.id, 't1');
    expect(trip.start, DateTime.utc(2026, 10, 1, 3, 10));
    expect(trip.end, DateTime.utc(2026, 10, 1, 3, 32));
    expect(trip.amount, 2400);
    expect(trip.payment, PaymentMethod.card);
    expect(trip.commission, 360);
  });

  group('amount', () {
    test('must be greater than 0', () {
      expect(errorsOf({...sample(), 'amount': 0}),
          {'amount': 'Сумма должна быть больше 0'});
      expect(errorsOf({...sample(), 'amount': -100}).keys, ['amount']);
    });

    test('must be a JSON integer', () {
      for (final value in [2400.5, 2400.0, '2400', null]) {
        expect(errorsOf({...sample(), 'amount': value}),
            {'amount': 'Сумма должна быть целым числом'},
            reason: '$value');
      }
    });

    test('decimal from real JSON text is rejected', () {
      final json = jsonDecode(
          '{"id":"t1","start":"2026-10-01T08:10:00+05:00",'
          '"end":"2026-10-01T08:32:00+05:00","amount":2400.0,'
          '"payment":"card","commission":360}') as Map<String, Object?>;
      expect(errorsOf(json).keys, ['amount']);
    });
  });

  group('time', () {
    test('end equal to start is rejected', () {
      expect(errorsOf({...sample(), 'end': '2026-10-01T08:10:00+05:00'}),
          {'end': 'Окончание должно быть позже начала'});
    });

    test('end before start is rejected', () {
      expect(errorsOf({...sample(), 'end': '2026-10-01T07:00:00+05:00'}),
          {'end': 'Окончание должно быть позже начала'});
    });

    test('same moment written in another offset counts as equal', () {
      expect(errorsOf({...sample(), 'end': '2026-10-01T03:10:00Z'}),
          {'end': 'Окончание должно быть позже начала'});
    });

    test('timestamps without offset are rejected as ambiguous', () {
      expect(errorsOf({...sample(), 'start': '2026-10-01T08:10:00'}),
          {'start': 'Некорректное время начала'});
    });

    test('impossible dates and times are rejected', () {
      for (final value in [
        '2026-02-30T08:10:00+05:00',
        '2026-10-01T25:00:00+05:00',
        'yesterday',
        1696130000,
      ]) {
        expect(errorsOf({...sample(), 'start': value}).keys, ['start'],
            reason: '$value');
      }
    });

    test('UTC Z and fractional seconds are accepted', () {
      expect(
        errorsOf({
          ...sample(),
          'start': '2026-10-01T03:10:00Z',
          'end': '2026-10-01T03:32:00.250Z',
        }),
        isEmpty,
      );
    });
  });

  group('commission', () {
    test('0 and equal to amount are allowed', () {
      expect(errorsOf({...sample(), 'commission': 0}), isEmpty);
      expect(errorsOf({...sample(), 'commission': 2400}), isEmpty);
    });

    test('negative is rejected', () {
      expect(errorsOf({...sample(), 'commission': -1}),
          {'commission': 'Комиссия не может быть отрицательной'});
    });

    test('greater than amount is rejected', () {
      expect(errorsOf({...sample(), 'commission': 2401}),
          {'commission': 'Комиссия не может превышать сумму'});
    });

    test('must be an integer', () {
      expect(errorsOf({...sample(), 'commission': 360.5}),
          {'commission': 'Комиссия должна быть целым числом'});
    });
  });

  test('payment must be cash or card', () {
    for (final value in ['bitcoin', 'CASH', null]) {
      expect(errorsOf({...sample(), 'payment': value}),
          {'payment': 'Выберите способ оплаты: наличные или карта'},
          reason: '$value');
    }
  });

  group('id', () {
    test('must be a non-empty string', () {
      for (final value in ['', '   ', null, 42]) {
        expect(errorsOf({...sample(), 'id': value}),
            {'id': 'Не указан id поездки'},
            reason: '$value');
      }
    });

    test('is limited to 64 characters', () {
      expect(errorsOf({...sample(), 'id': 'x' * 64}), isEmpty);
      expect(errorsOf({...sample(), 'id': 'x' * 65}),
          {'id': 'id не может быть длиннее 64 символов'});
    });
  });

  test('collects every error at once', () {
    expect(errorsOf({}).keys,
        unorderedEquals(['id', 'start', 'end', 'amount', 'commission', 'payment']));
  });

  test('ignores unknown fields', () {
    expect(errorsOf({...sample(), 'driver': 'Азамат'}), isEmpty);
  });

  group('Trip', () {
    Trip valid(Map<String, Object?> json) =>
        (validateTrip(json) as ValidTrip).trip;

    test('equality compares instants, not strings', () {
      final local = valid(sample());
      final utc = valid({
        ...sample(),
        'start': '2026-10-01T03:10:00Z',
        'end': '2026-10-01T03:32:00Z',
      });
      expect(utc, local);
      expect(utc.hashCode, local.hashCode);
      expect(valid({...sample(), 'amount': 2500}), isNot(local));
    });

    test('toJson renders driver offset and round-trips via fromJson', () {
      final trip = valid(sample());
      final json = trip.toJson(plus5);
      expect(json, sample());
      expect(Trip.fromJson(jsonDecode(jsonEncode(json)) as Map<String, Object?>),
          trip);
    });

    test('fromJson throws FormatException for invalid data', () {
      expect(() => Trip.fromJson({...sample(), 'amount': 0}),
          throwsFormatException);
    });
  });
}
