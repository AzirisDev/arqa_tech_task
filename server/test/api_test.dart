import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shift_diary_server/shift_diary_server.dart';
import 'package:test/test.dart';
import 'package:trip_core/trip_core.dart';

import 'helpers.dart';

void main() {
  late TripRepository repo;
  late Handler api;

  setUp(() {
    repo = TripRepository.inMemory(driverOffset: plus5);
    api = buildApi(repo);
  });
  tearDown(() => repo.close());

  /// Calls the handler directly (no socket). [body] may be a raw string.
  Future<(int, Object?)> call(
    String method,
    String path, [
    Object? body,
  ]) async {
    final response = await api(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        body: body == null ? null : (body is String ? body : jsonEncode(body)),
      ),
    );
    expect(response.headers['content-type'], startsWith('application/json'));
    final text = await response.readAsString();
    return (response.statusCode, text.isEmpty ? null : jsonDecode(text));
  }

  final t1 = sampleTrip().toJson(plus5);

  group('POST /api/trips', () {
    test('creates a trip: 201 with the stored trip', () async {
      final (status, body) = await call('POST', '/api/trips', t1);
      expect(status, 201);
      expect(body, t1);
      expect(repo.count(), 1);
    });

    test('re-sending the same trip: 200, no duplicate', () async {
      await call('POST', '/api/trips', t1);
      final (status, body) = await call('POST', '/api/trips', t1);
      expect(status, 200);
      expect(body, t1);
      expect(repo.count(), 1);
    });

    test('same id with different data: 409, original kept', () async {
      await call('POST', '/api/trips', t1);
      final (status, body) = await call('POST', '/api/trips', {
        ...t1,
        'amount': 9999,
      });
      expect(status, 409);
      body as Map<String, Object?>;
      expect(body['error'], 'conflict');
      expect((body['existing'] as Map)['amount'], 2400);
      expect(repo.findById('t1')!.amount, 2400);
    });

    test(
      're-sending the echoed trip (fractional start) is a 200 replay',
      () async {
        final (status, echoed) = await call('POST', '/api/trips', {
          ...t1,
          'start': '2026-10-01T08:10:00.250+05:00',
        });
        expect(status, 201);
        final (replayStatus, _) = await call('POST', '/api/trips', echoed);
        expect(replayStatus, 200);
        expect(repo.count(), 1);
      },
    );

    test('20 parallel identical requests store exactly one trip', () async {
      final results = await Future.wait(
        List.generate(20, (_) => call('POST', '/api/trips', t1)),
      );
      final statuses = results.map((r) => r.$1).toList();
      expect(statuses.where((s) => s == 201), hasLength(1));
      expect(statuses.where((s) => s == 200), hasLength(19));
      expect(repo.count(), 1);
    });

    test('invalid trip: 400 with field errors, nothing stored', () async {
      final (status, body) = await call('POST', '/api/trips', {
        ...t1,
        'amount': 0,
        'end': '2026-10-01T08:00:00+05:00',
      });
      expect(status, 400);
      expect(body, {
        'errors': {
          'amount': 'Сумма должна быть больше 0',
          'end': 'Окончание должно быть позже начала',
        },
      });
      expect(repo.count(), 0);
    });

    test('malformed JSON: 400', () async {
      final (status, body) = await call('POST', '/api/trips', 'not json');
      expect(status, 400);
      expect((body as Map)['errors'], contains('_'));
    });

    test('JSON that is not an object: 400', () async {
      final (status, body) = await call('POST', '/api/trips', [t1]);
      expect(status, 400);
      expect((body as Map)['errors'], contains('_'));
    });
  });

  group('GET /api/days/<date>', () {
    setUp(() {
      repo.insert(sampleTrip());
      repo.insert(
        sampleTrip(
          id: 't2',
          start: '2026-10-01T09:05:00+05:00',
          end: '2026-10-01T09:20:00+05:00',
          amount: 1500,
          payment: PaymentMethod.cash,
          commission: 225,
        ),
      );
      repo.insert(
        sampleTrip(
          id: 'other-day',
          start: '2026-10-02T08:00:00+05:00',
          end: '2026-10-02T08:30:00+05:00',
        ),
      );
    });

    test('returns trips of that driver-local day with summary', () async {
      final (status, body) = await call('GET', '/api/days/2026-10-01');
      expect(status, 200);
      body as Map<String, Object?>;
      expect(body['date'], '2026-10-01');
      expect((body['trips'] as List).map((t) => (t as Map)['id']), [
        't1',
        't2',
      ]);
      expect(body['summary'], {
        'tripCount': 2,
        'revenue': 3900,
        'commission': 585,
        'net': 3315,
        'cash': {'count': 1, 'revenue': 1500, 'commission': 225},
        'card': {'count': 1, 'revenue': 2400, 'commission': 360},
      });
    });

    test('day without trips: 200 with zero summary', () async {
      final (status, body) = await call('GET', '/api/days/2026-10-07');
      expect(status, 200);
      body as Map<String, Object?>;
      expect(body['trips'], isEmpty);
      expect((body['summary'] as Map)['tripCount'], 0);
    });

    test('bad date: 400', () async {
      for (final date in ['2026-02-30', 'today', '01.10.2026']) {
        final (status, body) = await call('GET', '/api/days/$date');
        expect(status, 400, reason: date);
        expect((body as Map)['errors'], contains('date'));
      }
    });

    test('GET /api/days lists days with counts', () async {
      final (status, body) = await call('GET', '/api/days');
      expect(status, 200);
      expect(body, [
        {'date': '2026-10-01', 'tripCount': 2},
        {'date': '2026-10-02', 'tripCount': 1},
      ]);
    });
  });

  test('unknown route: 404 JSON', () async {
    final (status, body) = await call('GET', '/nope');
    expect(status, 404);
    expect(body, {'error': 'not_found'});
  });
}
