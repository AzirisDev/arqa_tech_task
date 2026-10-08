import 'dart:convert';
import 'dart:io';

import 'package:shift_diary_server/shift_diary_server.dart';
import 'package:test/test.dart';
import 'package:trip_core/trip_core.dart';

import 'helpers.dart';

void main() {
  late TripRepository repo;

  setUp(() => repo = TripRepository.inMemory(driverOffset: plus5));
  tearDown(() => repo.close());

  test('imports valid entries and skips invalid ones', () {
    final t1 = sampleTrip().toJson(plus5);
    final t2 = sampleTrip(id: 't2').toJson(plus5);
    final report = seedIfEmpty(repo, jsonEncode([
      t1,
      t2,
      {...t1, 'id': 'bad', 'amount': 0},
      'garbage',
      {...t1, 'amount': 1}, // same id as t1, different data
    ]))!;

    expect(report.imported, 2);
    expect(report.skipped, hasLength(3));
    expect(repo.count(), 2);
  });

  test('does nothing when the database already has trips', () {
    repo.insert(sampleTrip());
    expect(seedIfEmpty(repo, '[]'), isNull);
    expect(repo.count(), 1);
  });

  test('rejects a file that is not a JSON array', () {
    expect(() => seedIfEmpty(repo, '{}'), throwsFormatException);
  });

  test('bundled data/trips.json is fully valid', () {
    final report =
        seedIfEmpty(repo, File('data/trips.json').readAsStringSync())!;
    expect(report.skipped, isEmpty);
    expect(report.imported, 13);

    final oct2 = summarize(repo.tripsOn(const LocalDate(2026, 10, 2)));
    expect(oct2.tripCount, 3); // includes the 23:40 → 00:15 trip
    expect(oct2.revenue, 8100);
    expect(oct2.net, 6885);

    final oct3 = summarize(repo.tripsOn(const LocalDate(2026, 10, 3)));
    expect(oct3.tripCount, 2);
    expect(oct3.card.count, 0);
    expect(oct3.net, 2635);
  });
}
