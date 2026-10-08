import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shift_diary/src/api/api_client.dart';
import 'package:shift_diary/src/day/day_controller.dart';
import 'package:trip_core/trip_core.dart';

import 'fakes.dart';

const oct1 = LocalDate(2026, 10, 1);
const oct5 = LocalDate(2026, 10, 5);
const today = LocalDate(2026, 10, 8);

void main() {
  test('init opens the latest day that has trips', () async {
    final api = FakeApiClient(
        days: [oct1, oct5], dayData: {oct5: dayOf(oct5, sampleTrips())});
    final controller = DayController(api: api, today: () => today);

    await controller.init();

    expect(controller.date, oct5);
    expect((controller.state as DayLoaded).data.trips, hasLength(2));
  });

  test('init does not override a day selected while days are loading',
      () async {
    final days = Completer<List<LocalDate>>();
    final api = FakeApiClient()..onFetchDays = () => days.future;
    final controller = DayController(api: api, today: () => today);

    final init = controller.init();
    await controller.select(oct1);
    days.complete([oct5]);
    await init;

    expect(controller.date, oct1);
  });

  test('init falls back to today when there are no trips', () async {
    final controller = DayController(api: FakeApiClient(), today: () => today);
    await controller.init();
    expect(controller.date, today);
    expect(controller.state, isA<DayLoaded>());
  });

  test('init falls back to today when the days request fails', () async {
    final api = FakeApiClient()
      ..onFetchDays = () async => throw const NetworkFailure();
    final controller = DayController(api: api, today: () => today);
    await controller.init();
    expect(controller.date, today);
  });

  test('next and previous move by one calendar day and refetch', () async {
    final api = FakeApiClient();
    final controller = DayController(api: api, today: () => oct1);

    await controller.select(oct1);
    await controller.next();
    expect(controller.date, const LocalDate(2026, 10, 2));
    await controller.previous();
    await controller.previous();
    expect(controller.date, const LocalDate(2026, 9, 30));
    expect(api.fetchedDates, [
      oct1,
      const LocalDate(2026, 10, 2),
      oct1,
      const LocalDate(2026, 9, 30),
    ]);
  });

  test('failure becomes DayError with a message for the driver', () async {
    final api = FakeApiClient()
      ..onFetchDay = (_) async => throw const NetworkFailure();
    final controller = DayController(api: api, today: () => oct1);

    await controller.select(oct1);

    expect(controller.state, isA<DayError>());
    expect((controller.state as DayError).message,
        const NetworkFailure().message);
  });

  test('a slow response for an old day does not overwrite the newer day',
      () async {
    final slow = Completer<DayData>();
    final api = FakeApiClient()
      ..onFetchDay = (date) =>
          date == oct1 ? slow.future : Future.value(dayOf(date, const []));
    final controller = DayController(api: api, today: () => oct1);

    final first = controller.select(oct1);
    await controller.select(oct5);
    slow.complete(dayOf(oct1, sampleTrips()));
    await first;

    expect(controller.date, oct5);
    expect((controller.state as DayLoaded).data.date, oct5);
  });

  test('refresh keeps the current content visible while loading', () async {
    final api = FakeApiClient(dayData: {oct1: dayOf(oct1, sampleTrips())});
    final controller = DayController(api: api, today: () => oct1);
    await controller.select(oct1);

    final pending = controller.refresh();
    expect(controller.state, isA<DayLoaded>());
    await pending;
    expect(controller.state, isA<DayLoaded>());
  });

  test('select shows loading until data arrives', () async {
    final gate = Completer<DayData>();
    final api = FakeApiClient()..onFetchDay = (_) => gate.future;
    final controller = DayController(api: api, today: () => oct1);

    final pending = controller.select(oct1);
    expect(controller.state, isA<DayLoading>());
    gate.complete(dayOf(oct1, const []));
    await pending;
    expect(controller.state, isA<DayLoaded>());
  });
}
