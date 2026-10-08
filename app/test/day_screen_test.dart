import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_diary/src/api/api_client.dart';
import 'package:shift_diary/src/day/day_screen.dart';
import 'package:shift_diary/src/format.dart';
import 'package:trip_core/trip_core.dart';

import 'fakes.dart';

const oct1 = LocalDate(2026, 10, 1);
const today = LocalDate(2026, 10, 8);

Future<void> pumpDay(WidgetTester tester, FakeApiClient api) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DayScreen(api: api, today: () => today),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens the latest day and shows its summary and trips', (
    tester,
  ) async {
    final api = FakeApiClient(
      days: [oct1],
      dayData: {oct1: dayOf(oct1, sampleTrips())},
    );
    await pumpDay(tester, api);

    expect(find.text('чт, 1 окт'), findsOneWidget);
    expect(find.text('На руки'), findsOneWidget);
    expect(find.text(formatMoney(3315)), findsOneWidget); // net
    expect(find.text(formatMoney(3900)), findsOneWidget); // revenue
    expect(find.text(formatMoney(585)), findsOneWidget); // commission
    expect(find.text('1 · ${formatMoney(1500)}'), findsOneWidget); // cash
    expect(find.text('1 · ${formatMoney(2400)}'), findsOneWidget); // card
    expect(find.text('08:10–08:32 · 22 мин'), findsOneWidget);
    expect(find.text('09:05–09:20 · 15 мин'), findsOneWidget);
  });

  testWidgets('arrows switch days and refetch', (tester) async {
    final api = FakeApiClient(
      days: [oct1],
      dayData: {oct1: dayOf(oct1, sampleTrips())},
    );
    await pumpDay(tester, api);

    await tester.tap(find.byKey(const Key('next-day')));
    await tester.pumpAndSettle();
    expect(find.text('пт, 2 окт'), findsOneWidget);
    expect(find.text('Нет поездок за этот день'), findsOneWidget);

    await tester.tap(find.byKey(const Key('prev-day')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('prev-day')));
    await tester.pumpAndSettle();
    expect(find.text('ср, 30 сен'), findsOneWidget);
    expect(api.fetchedDates, [
      oct1,
      const LocalDate(2026, 10, 2),
      oct1,
      const LocalDate(2026, 9, 30),
    ]);
  });

  testWidgets('error state offers a retry', (tester) async {
    var attempts = 0;
    final api = FakeApiClient(days: [oct1])
      ..onFetchDay = (date) async {
        if (attempts++ == 0) throw const NetworkFailure();
        return dayOf(date, sampleTrips());
      };
    await pumpDay(tester, api);

    expect(find.text(const NetworkFailure().message), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text(formatMoney(3315)), findsOneWidget);
  });

  testWidgets('a trip saved from the form appears on its day', (tester) async {
    final api = FakeApiClient();
    api.onSaveTrip = (trip) async {
      final date = LocalDate.of(trip.start, plus5);
      api.dayData[date] = dayOf(date, [trip]);
      return trip;
    };
    await pumpDay(tester, api); // no trips anywhere → opens today

    expect(find.text('чт, 8 окт'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-trip')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('start-time')), '08:10');
    await tester.enterText(find.byKey(const Key('end-time')), '08:32');
    await tester.enterText(find.byKey(const Key('amount')), '2400');
    await tester.enterText(find.byKey(const Key('commission')), '360');
    await tester.ensureVisible(find.text('Наличные'));
    await tester.tap(find.text('Наличные'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();

    expect(find.text('08:10–08:32 · 22 мин'), findsOneWidget);
    expect(find.text(formatMoney(2040)), findsOneWidget); // net 2400 − 360
  });

  testWidgets('closing the form after a conflict refreshes the day', (
    tester,
  ) async {
    final api = FakeApiClient(
      days: [oct1],
      dayData: {oct1: dayOf(oct1, sampleTrips())},
    );
    api.onSaveTrip = (_) async => throw const ConflictFailure();
    await pumpDay(tester, api);

    await tester.tap(find.byKey(const Key('add-trip')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('start-time')), '08:10');
    await tester.enterText(find.byKey(const Key('end-time')), '08:32');
    await tester.enterText(find.byKey(const Key('amount')), '2400');
    await tester.enterText(find.byKey(const Key('commission')), '360');
    await tester.ensureVisible(find.text('Наличные'));
    await tester.tap(find.text('Наличные'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('submit'))); // now «Закрыть»
    await tester.pumpAndSettle();

    expect(api.fetchedDates.sublist(api.fetchedDates.length - 2), [oct1, oct1]);
    expect(find.text('На руки'), findsOneWidget);
  });
}
