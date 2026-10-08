import 'package:sqlite3/sqlite3.dart';
import 'package:trip_core/trip_core.dart';

enum InsertOutcome { created, replayed, conflict }

class InsertResult {
  const InsertResult(this.outcome, this.trip);

  final InsertOutcome outcome;

  /// The trip as stored. For [InsertOutcome.conflict] this is the existing
  /// trip, not the rejected one.
  final Trip trip;
}

class DayCount {
  const DayCount(this.date, this.tripCount);

  final LocalDate date;
  final int tripCount;
}

/// SQLite-backed trip storage. Trips are bucketed by the driver-local date of
/// their start, computed once on insert with [driverOffset].
class TripRepository {
  TripRepository(this._db, {required this.driverOffset}) {
    _db.execute(_schema);
  }

  TripRepository.inMemory({required Duration driverOffset})
    : this(sqlite3.openInMemory(), driverOffset: driverOffset);

  TripRepository.open(String path, {required Duration driverOffset})
    : this(sqlite3.open(path), driverOffset: driverOffset);

  static const _schema = '''
    CREATE TABLE IF NOT EXISTS trips (
      id          TEXT PRIMARY KEY,
      start_utc   TEXT NOT NULL,
      end_utc     TEXT NOT NULL,
      local_date  TEXT NOT NULL,
      amount      INTEGER NOT NULL CHECK (amount > 0),
      commission  INTEGER NOT NULL CHECK (commission >= 0 AND commission <= amount),
      payment     TEXT NOT NULL CHECK (payment IN ('cash', 'card'))
    );
    CREATE INDEX IF NOT EXISTS trips_local_date ON trips (local_date, start_utc);
  ''';

  final Database _db;
  final Duration driverOffset;

  /// Inserts [trip] unless a trip with the same id exists.
  ///
  /// The primary key makes this atomic: there is no check-then-insert window,
  /// so concurrent identical requests can never produce two rows.
  InsertResult insert(Trip trip) {
    _db.execute(
      'INSERT INTO trips '
      '(id, start_utc, end_utc, local_date, amount, commission, payment) '
      'VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT (id) DO NOTHING',
      [
        trip.id,
        trip.start.toIso8601String(),
        trip.end.toIso8601String(),
        LocalDate.of(trip.start, driverOffset).toString(),
        trip.amount,
        trip.commission,
        trip.payment.name,
      ],
    );
    if (_db.updatedRows == 1) return InsertResult(InsertOutcome.created, trip);

    final existing = findById(trip.id)!;
    return InsertResult(
      existing == trip ? InsertOutcome.replayed : InsertOutcome.conflict,
      existing,
    );
  }

  Trip? findById(String id) {
    final rows = _db.select('SELECT * FROM trips WHERE id = ?', [id]);
    return rows.isEmpty ? null : _toTrip(rows.first);
  }

  List<Trip> tripsOn(LocalDate date) => [
    for (final row in _db.select(
      'SELECT * FROM trips WHERE local_date = ? ORDER BY start_utc, id',
      [date.toString()],
    ))
      _toTrip(row),
  ];

  List<DayCount> days() => [
    for (final row in _db.select(
      'SELECT local_date, COUNT(*) AS trip_count FROM trips '
      'GROUP BY local_date ORDER BY local_date',
    ))
      DayCount(
        LocalDate.tryParse(row['local_date'] as String)!,
        row['trip_count'] as int,
      ),
  ];

  int count() =>
      _db.select('SELECT COUNT(*) AS n FROM trips').first['n'] as int;

  void close() => _db.close();

  Trip _toTrip(Row row) => Trip(
    id: row['id'] as String,
    start: DateTime.parse(row['start_utc'] as String),
    end: DateTime.parse(row['end_utc'] as String),
    amount: row['amount'] as int,
    payment: PaymentMethod.tryParse(row['payment'])!,
    commission: row['commission'] as int,
  );
}
