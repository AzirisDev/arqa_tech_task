import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:trip_core/trip_core.dart';

import 'trip_repository.dart';

Handler buildApi(TripRepository repo) {
  final offset = repo.driverOffset;
  final router = Router(
    notFoundHandler: (Request request) => _json(404, {'error': 'not_found'}),
  );

  router.get(
    '/api/days',
    (Request request) => _json(200, [
      for (final day in repo.days())
        {'date': day.date.toString(), 'tripCount': day.tripCount},
    ]),
  );

  router.get('/api/days/<date>', (Request request, String date) {
    final day = LocalDate.tryParse(date);
    if (day == null) {
      return _json(400, {
        'errors': {'date': 'Дата должна быть в формате YYYY-MM-DD'},
      });
    }
    final trips = repo.tripsOn(day);
    return _json(200, {
      'date': day.toString(),
      'summary': summarize(trips).toJson(),
      'trips': [for (final trip in trips) trip.toJson(offset)],
    });
  });

  router.post('/api/trips', (Request request) async {
    final Object? body;
    try {
      body = jsonDecode(await request.readAsString());
    } on FormatException {
      return _json(400, {
        'errors': {'_': 'Тело запроса — не JSON'},
      });
    }
    if (body is! Map<String, Object?>) {
      return _json(400, {
        'errors': {'_': 'Ожидается JSON-объект поездки'},
      });
    }

    switch (validateTrip(body)) {
      case InvalidTrip(:final errors):
        return _json(400, {'errors': errors});
      case ValidTrip(:final trip):
        final result = repo.insert(trip);
        final stored = result.trip.toJson(offset);
        return switch (result.outcome) {
          InsertOutcome.created => _json(201, stored),
          InsertOutcome.replayed => _json(200, stored),
          InsertOutcome.conflict => _json(409, {
            'error': 'conflict',
            'message':
                'Поездка с id "${trip.id}" уже сохранена с другими данными',
            'existing': stored,
          }),
        };
    }
  });

  return const Pipeline().addMiddleware(_catchErrors).addHandler(router.call);
}

Handler _catchErrors(Handler inner) => (Request request) async {
  try {
    return await inner(request);
  } catch (error, stack) {
    stderr.writeln(
      'Unhandled error on ${request.method} ${request.requestedUri}: '
      '$error\n$stack',
    );
    return _json(500, {'error': 'internal'});
  }
};

Response _json(int status, Object body) => Response(
  status,
  body: jsonEncode(body),
  headers: {'content-type': 'application/json; charset=utf-8'},
);
