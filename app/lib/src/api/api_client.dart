import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:trip_core/trip_core.dart';

/// Everything [ApiClient] throws. [message] is ready to show to the driver.
sealed class ApiFailure implements Exception {
  const ApiFailure();

  String get message;
}

class ValidationFailure extends ApiFailure {
  const ValidationFailure(this.errors);

  /// Field name → message, same keys as `validateTrip`.
  final Map<String, String> errors;

  @override
  String get message => errors.values.join('\n');
}

class ConflictFailure extends ApiFailure {
  const ConflictFailure();

  @override
  String get message => 'Эта поездка уже сохранена с другими данными';
}

class NetworkFailure extends ApiFailure {
  const NetworkFailure();

  @override
  String get message =>
      'Нет связи с сервером. Проверьте подключение и повторите.';
}

class ServerFailure extends ApiFailure {
  const ServerFailure(this.statusCode);

  final int statusCode;

  @override
  String get message => 'Ошибка сервера ($statusCode). Повторите позже.';
}

/// Response of `GET /api/days/{date}`.
class DayData {
  const DayData({
    required this.date,
    required this.summary,
    required this.trips,
  });

  final LocalDate date;
  final DaySummary summary;
  final List<Trip> trips;
}

class ApiClient {
  ApiClient({
    required Uri baseUrl,
    required this.driverOffset,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 10),
  }) : _baseUrl = baseUrl,
       _http = httpClient ?? http.Client(),
       _timeout = timeout;

  final Uri _baseUrl;
  final http.Client _http;
  final Duration _timeout;

  /// Offset used to write timestamps; must match the server's
  /// `DRIVER_UTC_OFFSET`.
  final Duration driverOffset;

  /// Dates that have trips, ascending.
  Future<List<LocalDate>> fetchDays() async {
    final response = await _send(() => _http.get(_uri('/api/days')));
    _expectOk(response);
    return _parse(
      response,
      (json) => [
        for (final entry in json as List)
          LocalDate.tryParse((entry as Map)['date'] as String)!,
      ],
    );
  }

  Future<DayData> fetchDay(LocalDate date) async {
    final response = await _send(() => _http.get(_uri('/api/days/$date')));
    _expectOk(response);
    return _parse(response, (json) {
      final map = json as Map<String, Object?>;
      return DayData(
        date: date,
        summary: DaySummary.fromJson(map['summary'] as Map<String, Object?>),
        trips: [
          for (final trip in map['trips'] as List)
            Trip.fromJson(trip as Map<String, Object?>),
        ],
      );
    });
  }

  /// Saves [trip]. Safe to repeat with the same trip after a failure: the
  /// server answers 200 for a repeat, which counts as success here.
  Future<Trip> saveTrip(Trip trip) async {
    final response = await _send(
      () => _http.post(
        _uri('/api/trips'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode(trip.toJson(driverOffset)),
      ),
    );
    switch (response.statusCode) {
      case 200 || 201:
        return _parse(
          response,
          (json) => Trip.fromJson(json as Map<String, Object?>),
        );
      case 400:
        final errors = _parse(
          response,
          (json) => Map<String, String>.from((json as Map)['errors'] as Map),
        );
        throw ValidationFailure(errors);
      case 409:
        throw const ConflictFailure();
      default:
        throw ServerFailure(response.statusCode);
    }
  }

  Uri _uri(String path) => _baseUrl.resolve(path);

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException {
      throw const NetworkFailure();
    } on SocketException {
      throw const NetworkFailure();
    } on http.ClientException {
      throw const NetworkFailure();
    }
  }

  void _expectOk(http.Response response) {
    if (response.statusCode != 200) throw ServerFailure(response.statusCode);
  }

  /// Decodes the body and maps it with [read]; any shape mismatch is a
  /// server problem, not a crash.
  T _parse<T>(http.Response response, T Function(Object? json) read) {
    try {
      return read(jsonDecode(utf8.decode(response.bodyBytes)));
    } on FormatException {
      throw ServerFailure(response.statusCode);
    } on TypeError {
      throw ServerFailure(response.statusCode);
    }
  }
}
