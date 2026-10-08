import 'dart:io';

import 'package:shift_diary_server/shift_diary_server.dart';
import 'package:test/test.dart';
import 'package:trip_core/trip_core.dart';

import 'helpers.dart';

void main() {
  late TripRepository repo;

  setUp(() => repo = TripRepository.inMemory(driverOffset: plus5));
  tearDown(() => repo.close());

  group('insert idempotency', () {
    test('new trip is created', () {
      final result = repo.insert(sampleTrip());
      expect(result.outcome, InsertOutcome.created);
      expect(repo.count(), 1);
      expect(repo.findById('t1'), sampleTrip());
    });

    test('re-sending the same trip is a replay, not a duplicate', () {
      repo.insert(sampleTrip());
      final result = repo.insert(sampleTrip());
      expect(result.outcome, InsertOutcome.replayed);
      expect(result.trip, sampleTrip());
      expect(repo.count(), 1);
    });

    test('same moments written in another offset are still a replay', () {
      repo.insert(sampleTrip());
      final result = repo.insert(sampleTrip(
        start: '2026-10-01T03:10:00Z',
        end: '2026-10-01T03:32:00Z',
      ));
      expect(result.outcome, InsertOutcome.replayed);
      expect(repo.count(), 1);
    });

    test('same id with different data is a conflict and keeps the original',
        () {
      repo.insert(sampleTrip());
      final result = repo.insert(sampleTrip(amount: 9999));
      expect(result.outcome, InsertOutcome.conflict);
      expect(result.trip.amount, 2400);
      expect(repo.findById('t1')!.amount, 2400);
      expect(repo.count(), 1);
    });
  });

  test('tripsOn groups by driver-local date of start, sorted by start', () {
    repo.insert(sampleTrip(
      id: 'late',
      start: '2026-10-01T23:40:00+05:00',
      end: '2026-10-02T00:15:00+05:00',
    ));
    // 00:30 at +05:00 is 19:30Z on 2026-09-30 — must still be October 1st.
    repo.insert(sampleTrip(
      id: 'early',
      start: '2026-10-01T00:30:00+05:00',
      end: '2026-10-01T00:50:00+05:00',
    ));
    repo.insert(sampleTrip(
      id: 'next',
      start: '2026-10-02T09:00:00+05:00',
      end: '2026-10-02T09:20:00+05:00',
    ));

    expect(repo.tripsOn(const LocalDate(2026, 10, 1)).map((t) => t.id),
        ['early', 'late']);
    expect(repo.tripsOn(const LocalDate(2026, 10, 2)).map((t) => t.id),
        ['next']);
    expect(repo.tripsOn(const LocalDate(2026, 9, 30)), isEmpty);
  });

  test('days lists dates that have trips, ascending, with counts', () {
    repo.insert(sampleTrip(id: 'b', start: '2026-10-02T09:00:00+05:00',
        end: '2026-10-02T09:20:00+05:00'));
    repo.insert(sampleTrip(id: 'a1'));
    repo.insert(sampleTrip(id: 'a2', start: '2026-10-01T10:00:00+05:00',
        end: '2026-10-01T10:20:00+05:00'));

    final days = repo.days();
    expect(days.map((d) => d.date.toString()), ['2026-10-01', '2026-10-02']);
    expect(days.map((d) => d.tripCount), [2, 1]);
  });

  test('data survives reopening the database file', () {
    final dir = Directory.systemTemp.createTempSync('shift_diary_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/trips.db';

    final first = TripRepository.open(path, driverOffset: plus5);
    first.insert(sampleTrip());
    first.close();

    final reopened = TripRepository.open(path, driverOffset: plus5);
    addTearDown(reopened.close);
    expect(reopened.count(), 1);
    expect(reopened.insert(sampleTrip()).outcome, InsertOutcome.replayed);
  });
}
