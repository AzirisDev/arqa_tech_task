import 'package:shift_diary/src/api/api_client.dart';
import 'package:trip_core/trip_core.dart';

const plus5 = Duration(hours: 5);

Trip tripAt(
  String id,
  String start,
  String end,
  int amount,
  PaymentMethod payment,
  int commission,
) => Trip(
  id: id,
  start: DateTime.parse(start),
  end: DateTime.parse(end),
  amount: amount,
  payment: payment,
  commission: commission,
);

/// Assignment sample: two trips on 2026-10-01.
List<Trip> sampleTrips() => [
  tripAt(
    't1',
    '2026-10-01T08:10:00+05:00',
    '2026-10-01T08:32:00+05:00',
    2400,
    PaymentMethod.card,
    360,
  ),
  tripAt(
    't2',
    '2026-10-01T09:05:00+05:00',
    '2026-10-01T09:20:00+05:00',
    1500,
    PaymentMethod.cash,
    225,
  ),
];

DayData dayOf(LocalDate date, List<Trip> trips) =>
    DayData(date: date, summary: summarize(trips), trips: trips);

/// In-memory [ApiClient]. By default serves [days] and [dayData] (missing
/// days are empty) and echoes saved trips; hooks override per test.
class FakeApiClient implements ApiClient {
  FakeApiClient({List<LocalDate>? days, Map<LocalDate, DayData>? dayData})
    : days = days ?? [],
      dayData = dayData ?? {};

  @override
  final Duration driverOffset = plus5;

  final List<LocalDate> days;
  final Map<LocalDate, DayData> dayData;

  Future<List<LocalDate>> Function()? onFetchDays;
  Future<DayData> Function(LocalDate date)? onFetchDay;
  Future<Trip> Function(Trip trip)? onSaveTrip;

  final fetchedDates = <LocalDate>[];
  final savedTrips = <Trip>[];

  @override
  Future<List<LocalDate>> fetchDays() =>
      onFetchDays?.call() ?? Future.value(days);

  @override
  Future<DayData> fetchDay(LocalDate date) {
    fetchedDates.add(date);
    return onFetchDay?.call(date) ??
        Future.value(dayData[date] ?? dayOf(date, const []));
  }

  @override
  Future<Trip> saveTrip(Trip trip) {
    savedTrips.add(trip);
    return onSaveTrip?.call(trip) ?? Future.value(trip);
  }
}
