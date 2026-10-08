import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_diary/src/add_trip/add_trip_screen.dart';
import 'package:shift_diary/src/api/api_client.dart';
import 'package:trip_core/trip_core.dart';

import 'fakes.dart';

const day = LocalDate(2026, 10, 1);

/// Opens the form from a host route so that popping it works like in the app.
/// Returns the list that receives the popped result.
Future<List<Trip?>> openForm(WidgetTester tester, FakeApiClient api) async {
  final results = <Trip?>[];
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async => results.add(
              await Navigator.of(context).push<Trip>(MaterialPageRoute(
                builder: (_) => AddTripScreen(
                  api: api,
                  initialDate: day,
                  newId: () => 'fixed-id',
                ),
              )),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

Future<void> fill(
  WidgetTester tester, {
  String start = '08:10',
  String end = '08:32',
  String amount = '2400',
  String commission = '360',
}) async {
  await tester.enterText(find.byKey(const Key('start-time')), start);
  await tester.enterText(find.byKey(const Key('end-time')), end);
  await tester.enterText(find.byKey(const Key('amount')), amount);
  await tester.enterText(find.byKey(const Key('commission')), commission);
  await tester.ensureVisible(find.text('Карта'));
  await tester.tap(find.text('Карта'));
  await tester.pump();
}

Future<void> submit(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty form shows every field error and does not call server',
      (tester) async {
    final api = FakeApiClient();
    await openForm(tester, api);

    await submit(tester);

    expect(find.text('Некорректное время начала'), findsOneWidget);
    expect(find.text('Некорректное время окончания'), findsOneWidget);
    expect(find.text('Сумма должна быть целым числом'), findsOneWidget);
    expect(find.text('Комиссия должна быть целым числом'), findsOneWidget);
    expect(find.text('Выберите способ оплаты: наличные или карта'),
        findsOneWidget);
    expect(api.savedTrips, isEmpty);
  });

  testWidgets('end before start is rejected locally', (tester) async {
    final api = FakeApiClient();
    await openForm(tester, api);

    await fill(tester, start: '09:00', end: '08:00');
    await submit(tester);

    expect(find.text('Окончание должно быть позже начала'), findsOneWidget);
    expect(api.savedTrips, isEmpty);
  });

  testWidgets('editing a field clears its error', (tester) async {
    final api = FakeApiClient();
    await openForm(tester, api);

    await submit(tester);
    expect(find.text('Сумма должна быть целым числом'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('amount')), '1000');
    await tester.pump();

    expect(find.text('Сумма должна быть целым числом'), findsNothing);
    expect(find.text('Некорректное время начала'), findsOneWidget);
  });

  testWidgets('changing start clears the end-order error', (tester) async {
    final api = FakeApiClient();
    await openForm(tester, api);

    await fill(tester, start: '09:00', end: '08:00');
    await submit(tester);
    expect(find.text('Окончание должно быть позже начала'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('start-time')), '07:00');
    await tester.pump();

    expect(find.text('Окончание должно быть позже начала'), findsNothing);
  });

  testWidgets('valid trip is saved in driver offset and returned',
      (tester) async {
    final api = FakeApiClient();
    final results = await openForm(tester, api);

    await fill(tester);
    await submit(tester);

    final saved = api.savedTrips.single;
    expect(saved.id, 'fixed-id');
    expect(saved.start, DateTime.parse('2026-10-01T08:10:00+05:00'));
    expect(saved.end, DateTime.parse('2026-10-01T08:32:00+05:00'));
    expect(saved.amount, 2400);
    expect(saved.commission, 360);
    expect(saved.payment, PaymentMethod.card);
    expect(results.single, saved);
  });

  testWidgets('"ends next day" moves the end to the following date',
      (tester) async {
    final api = FakeApiClient();
    await openForm(tester, api);

    await fill(tester, start: '23:40', end: '00:15');
    await tester.ensureVisible(find.byKey(const Key('ends-next-day')));
    await tester.tap(find.byKey(const Key('ends-next-day')));
    await submit(tester);

    expect(api.savedTrips.single.end,
        DateTime.parse('2026-10-02T00:15:00+05:00'));
  });

  testWidgets('retry after a network failure re-sends the same id',
      (tester) async {
    var attempts = 0;
    final api = FakeApiClient()
      ..onSaveTrip = (trip) async {
        if (attempts++ == 0) throw const NetworkFailure();
        return trip;
      };
    final results = await openForm(tester, api);

    await fill(tester);
    await submit(tester);

    expect(find.text(const NetworkFailure().message), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);

    await submit(tester);

    expect(api.savedTrips.map((t) => t.id), ['fixed-id', 'fixed-id']);
    expect(results.single?.id, 'fixed-id');
  });

  testWidgets('a conflict closes the form instead of offering a retry',
      (tester) async {
    final api = FakeApiClient()
      ..onSaveTrip = (_) async => throw const ConflictFailure();
    final results = await openForm(tester, api);

    await fill(tester);
    await submit(tester);

    expect(find.text(const ConflictFailure().message), findsOneWidget);
    expect(find.text('Закрыть'), findsOneWidget);

    await submit(tester);

    expect(results, [null]);
    expect(api.savedTrips, hasLength(1));
  });

  testWidgets('server validation errors appear under their fields',
      (tester) async {
    final api = FakeApiClient()
      ..onSaveTrip = (_) async => throw const ValidationFailure(
          {'commission': 'Комиссия не может превышать сумму'});
    await openForm(tester, api);

    await fill(tester);
    await submit(tester);

    expect(find.text('Комиссия не может превышать сумму'), findsOneWidget);
  });
}
