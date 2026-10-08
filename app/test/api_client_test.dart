import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shift_diary/src/api/api_client.dart';
import 'package:trip_core/trip_core.dart';

const plus5 = Duration(hours: 5);
const day = LocalDate(2026, 10, 1);

final t1 = Trip(
  id: 't1',
  start: DateTime.parse('2026-10-01T08:10:00+05:00'),
  end: DateTime.parse('2026-10-01T08:32:00+05:00'),
  amount: 2400,
  payment: PaymentMethod.card,
  commission: 360,
);

http.Response jsonResponse(Object body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

ApiClient clientWith(MockClientHandler handler) => ApiClient(
      baseUrl: Uri.parse('http://test.local'),
      driverOffset: plus5,
      httpClient: MockClient(handler),
    );

void main() {
  test('fetchDay requests the day and parses summary and trips', () async {
    late Uri requested;
    final api = clientWith((request) async {
      requested = request.url;
      return jsonResponse({
        'date': '2026-10-01',
        'summary': summarize([t1]).toJson(),
        'trips': [t1.toJson(plus5)],
      }, 200);
    });

    final data = await api.fetchDay(day);

    expect(requested.path, '/api/days/2026-10-01');
    expect(data.date, day);
    expect(data.summary, summarize([t1]));
    expect(data.trips, [t1]);
  });

  test('fetchDays returns dates in server order', () async {
    final api = clientWith((_) async => jsonResponse([
          {'date': '2026-10-01', 'tripCount': 5},
          {'date': '2026-10-05', 'tripCount': 3},
        ], 200));

    expect(await api.fetchDays(),
        [const LocalDate(2026, 10, 1), const LocalDate(2026, 10, 5)]);
  });

  test('saveTrip posts trip JSON in driver offset; 201 is success', () async {
    late Object? sent;
    final api = clientWith((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/trips');
      sent = jsonDecode(request.body);
      return jsonResponse(t1.toJson(plus5), 201);
    });

    expect(await api.saveTrip(t1), t1);
    expect(sent, {
      'id': 't1',
      'start': '2026-10-01T08:10:00+05:00',
      'end': '2026-10-01T08:32:00+05:00',
      'amount': 2400,
      'payment': 'card',
      'commission': 360,
    });
  });

  test('saveTrip treats 200 (already saved, replay) as success', () async {
    final api = clientWith((_) async => jsonResponse(t1.toJson(plus5), 200));
    expect(await api.saveTrip(t1), t1);
  });

  test('400 becomes ValidationFailure with field errors', () async {
    final api = clientWith((_) async => jsonResponse({
          'errors': {'amount': 'Сумма должна быть больше 0'},
        }, 400));

    await expectLater(
      api.saveTrip(t1),
      throwsA(isA<ValidationFailure>().having(
          (f) => f.errors, 'errors', {'amount': 'Сумма должна быть больше 0'})),
    );
  });

  test('409 becomes ConflictFailure', () async {
    final api = clientWith((_) async => jsonResponse({'error': 'conflict'}, 409));
    await expectLater(api.saveTrip(t1), throwsA(isA<ConflictFailure>()));
  });

  test('500 becomes ServerFailure', () async {
    final api = clientWith((_) async => jsonResponse({'error': 'internal'}, 500));
    await expectLater(
      api.fetchDay(day),
      throwsA(isA<ServerFailure>().having((f) => f.statusCode, 'status', 500)),
    );
  });

  test('connection error becomes NetworkFailure', () async {
    final api = clientWith((_) async => throw http.ClientException('refused'));
    await expectLater(api.fetchDays(), throwsA(isA<NetworkFailure>()));
  });

  test('malformed body becomes ServerFailure', () async {
    final api = clientWith((_) async => http.Response('oops', 200));
    await expectLater(api.fetchDay(day), throwsA(isA<ServerFailure>()));
  });
}
