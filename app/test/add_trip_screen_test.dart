import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_diary/src/add_trip/add_trip_screen.dart';
import 'package:shift_diary/src/api/api_client.dart';
import 'package:shift_diary/src/theme/app_theme.dart';
import 'package:trip_core/trip_core.dart';

import 'fakes.dart';

const day = LocalDate(2026, 10, 1);

/// Opens the form from a host route so that popping it works like in the app.
/// Returns the list that receives the popped result.
Future<List<Trip?>> openForm(WidgetTester tester, FakeApiClient api) async {
  final results = <Trip?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(Brightness.dark),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async => results.add(
                await Navigator.of(context).push<Trip>(
                  MaterialPageRoute(
                    builder: (_) => AddTripScreen(
                      api: api,
                      initialDate: day,
                      newId: () => 'fixed-id',
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
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
  testWidgets('empty form shows every field error and does not call server', (
    tester,
  ) async {
    final api = FakeApiClient();
    await openForm(tester, api);

    await submit(tester);

    expect(find.text('Некорректное время начала'), findsOneWidget);
    expect(find.text('Некорректное время окончания'), findsOneWidget);
    expect(find.text('Сумма должна быть целым числом'), findsOneWidget);
    expect(find.text('Комиссия должна быть целым числом'), findsOneWidget);
    expect(
      find.text('Выберите способ оплаты: наличные или карта'),
      findsOneWidget,
    );
    expect(api.savedTrips, isEmpty);
  });

  testWidgets('payment error is as small as the field errors', (tester) async {
    await openForm(tester, FakeApiClient());
    await submit(tester);

    double sizeOf(String text) => tester
        .renderObject<RenderParagraph>(find.text(text))
        .text
        .style!
        .fontSize!;
    expect(
      sizeOf('Выберите способ оплаты: наличные или карта'),
      sizeOf('Некорректное время начала'),
    );
  });

  testWidgets('tapping the date field opens the date picker', (tester) async {
    await openForm(tester, FakeApiClient());

    await tester.ensureVisible(find.byKey(const Key('date')));
    await tester.tap(find.byKey(const Key('date')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(
      find
          .descendant(
            of: find.byType(DatePickerDialog),
            matching: find.byType(TextButton),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('payment toggle starts empty and keeps the last choice', (
    tester,
  ) async {
    final api = FakeApiClient();
    await openForm(tester, api);

    await tester.enterText(find.byKey(const Key('start-time')), '08:10');
    await tester.enterText(find.byKey(const Key('end-time')), '08:32');
    await tester.enterText(find.byKey(const Key('amount')), '2400');
    await tester.enterText(find.byKey(const Key('commission')), '360');
    await submit(tester);

    expect(
      find.text('Выберите способ оплаты: наличные или карта'),
      findsOneWidget,
    );
    expect(api.savedTrips, isEmpty);

    await tester.ensureVisible(find.text('Карта'));
    await tester.tap(find.text('Карта'));
    await tester.pump();
    await tester.tap(find.text('Наличные'));
    await tester.pump();
    await submit(tester);

    expect(api.savedTrips.single.payment, PaymentMethod.cash);
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

  testWidgets('valid trip is saved in driver offset and returned', (
    tester,
  ) async {
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

  testWidgets('"ends next day" moves the end to the following date', (
    tester,
  ) async {
    final api = FakeApiClient();
    await openForm(tester, api);

    await fill(tester, start: '23:40', end: '00:15');
    await tester.ensureVisible(find.byKey(const Key('ends-next-day')));
    await tester.tap(find.byKey(const Key('ends-next-day')));
    await submit(tester);

    expect(
      api.savedTrips.single.end,
      DateTime.parse('2026-10-02T00:15:00+05:00'),
    );
  });

  testWidgets('retry after a network failure re-sends the same id', (
    tester,
  ) async {
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
    expect(find.text('ПОВТОРИТЬ'), findsOneWidget);

    await submit(tester);

    expect(api.savedTrips.map((t) => t.id), ['fixed-id', 'fixed-id']);
    expect(results.single?.id, 'fixed-id');
  });

  testWidgets('a conflict closes the form instead of offering a retry', (
    tester,
  ) async {
    final api = FakeApiClient()
      ..onSaveTrip = (_) async => throw const ConflictFailure();
    final results = await openForm(tester, api);

    await fill(tester);
    await submit(tester);

    expect(find.text(const ConflictFailure().message), findsOneWidget);
    expect(find.text('ЗАКРЫТЬ'), findsOneWidget);

    await submit(tester);

    expect(results, [null]);
    expect(api.savedTrips, hasLength(1));
  });

  testWidgets('server validation errors appear under their fields', (
    tester,
  ) async {
    final api = FakeApiClient()
      ..onSaveTrip = (_) async => throw const ValidationFailure({
        'commission': 'Комиссия не может превышать сумму',
      });
    await openForm(tester, api);

    await fill(tester);
    await submit(tester);

    expect(find.text('Комиссия не может превышать сумму'), findsOneWidget);
  });

  testWidgets('time typed as digits gets a colon', (tester) async {
    await openForm(tester, FakeApiClient());

    await tester.enterText(find.byKey(const Key('start-time')), '1023');
    await tester.pump();

    expect(find.text('10:23'), findsOneWidget);
  });

  testWidgets('hour-only times are saved as full times', (tester) async {
    final api = FakeApiClient();
    await openForm(tester, api);

    await fill(tester, start: '20', end: '2130');
    await submit(tester);

    final saved = api.savedTrips.single;
    expect(saved.start, DateTime.parse('2026-10-01T20:00:00+05:00'));
    expect(saved.end, DateTime.parse('2026-10-01T21:30:00+05:00'));
  });

  testWidgets('three digits mean H:MM', (tester) async {
    final api = FakeApiClient();
    await openForm(tester, api);

    await fill(tester, start: '930', end: '1000');
    await submit(tester);

    final saved = api.savedTrips.single;
    expect(saved.start, DateTime.parse('2026-10-01T09:30:00+05:00'));
    expect(saved.end, DateTime.parse('2026-10-01T10:00:00+05:00'));
  });

  testWidgets('leaving a time field shows the normalised time', (tester) async {
    await openForm(tester, FakeApiClient());

    await tester.enterText(find.byKey(const Key('start-time')), '930');
    await tester.pump();
    expect(find.text('9:30'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('end-time')));
    await tester.tap(find.byKey(const Key('end-time')));
    await tester.pump();

    expect(find.text('09:30'), findsOneWidget);
  });

  testWidgets('tapping outside a field closes the keyboard and normalises '
      'the time', (tester) async {
    await openForm(tester, FakeApiClient());

    await tester.enterText(find.byKey(const Key('start-time')), '930');
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.text('Новая поездка')));
    await tester.pump();

    expect(find.text('09:30'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('invalid time stays as typed when leaving the field', (
    tester,
  ) async {
    await openForm(tester, FakeApiClient());

    await tester.enterText(find.byKey(const Key('start-time')), '2460');
    await tester.pump();
    expect(find.text('24:60'), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.text('Новая поездка')));
    await tester.pump();

    expect(find.text('24:60'), findsOneWidget);
  });

  testWidgets('amount input groups thousands and saves the number', (
    tester,
  ) async {
    final api = FakeApiClient();
    await openForm(tester, api);

    await fill(tester, amount: '12000', commission: '1800');
    expect(find.text('12 000'), findsOneWidget);
    await submit(tester);

    expect(api.savedTrips.single.amount, 12000);
    expect(api.savedTrips.single.commission, 1800);
  });

  testWidgets('submit button uses the mock wording', (tester) async {
    await openForm(tester, FakeApiClient());
    expect(find.text('СОХРАНИТЬ ПОЕЗДКУ'), findsOneWidget);
  });

  group('accessibility', () {
    testWidgets('inputs carry their labels for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await openForm(tester, FakeApiClient());

      for (final (key, label) in [
        ('amount', 'Сумма (₸)'),
        ('commission', 'Комиссия (₸)'),
        ('start-time', 'Время начала'),
        ('end-time', 'Время окончания'),
      ]) {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.pump();
        // The time fields also announce their «ЧЧ:ММ» hint, so the label is
        // checked as a prefix rather than matched exactly.
        final node = tester.getSemantics(find.byKey(Key(key)));
        expect(node.label, startsWith(label), reason: key);
        expect(node, isSemantics(isTextField: true), reason: key);
      }
      handle.dispose();
    });

    testWidgets('the date field is a button labelled «Дата»', (tester) async {
      final handle = tester.ensureSemantics();
      await openForm(tester, FakeApiClient());

      await tester.ensureVisible(find.byKey(const Key('date')));
      await tester.pump();
      final node = tester.getSemantics(find.byKey(const Key('date')));
      expect(node, isSemantics(isButton: true));
      expect(node.label, contains('Дата'));
      handle.dispose();
    });

    testWidgets('tap targets are large enough', (tester) async {
      final handle = tester.ensureSemantics();
      await openForm(tester, FakeApiClient());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('the form does not overflow at 2x text on a small phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: AddTripScreen(api: FakeApiClient(), initialDate: day),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the toggle and date are disabled while saving', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final api = FakeApiClient()..onSaveTrip = (_) => Completer<Trip>().future;
      await openForm(tester, api);
      await fill(tester);
      expect(
        tester.getSemantics(find.text('Карта')),
        isSemantics(hasEnabledState: true, isEnabled: true),
      );
      await tester.tap(find.byKey(const Key('submit')));
      await tester.pump();

      for (final finder in [
        find.text('Карта'),
        find.byKey(const Key('date')),
      ]) {
        expect(
          tester.getSemantics(finder),
          isSemantics(hasEnabledState: true, isEnabled: false),
        );
      }
      handle.dispose();
    });

    testWidgets('the payment label is read with its toggle and error', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openForm(tester, FakeApiClient());
      await submit(tester);
      await tester.ensureVisible(find.text('Способ оплаты'));
      await tester.pump();

      final label = tester.getSemantics(find.text('Способ оплаты')).label;
      expect(label, contains('Способ оплаты'));
      expect(label, isNot(contains('Сумма')));
      expect(label, contains('Выберите способ оплаты'));

      // «Способ оплаты» is its own container holding the options (and not
      // the parent of the other fields), so it is read with the toggle.
      bool isInside(SemanticsNode? node, SemanticsNode ancestor) {
        for (var n = node; n != null; n = n.parent) {
          if (n.id == ancestor.id) return true;
        }
        return false;
      }

      final labelNode = tester.getSemantics(find.text('Способ оплаты'));
      expect(
        isInside(tester.getSemantics(find.text('Карта')), labelNode),
        isTrue,
      );
      expect(
        isInside(tester.getSemantics(find.text('Наличные')), labelNode),
        isTrue,
      );
      expect(
        isInside(
          tester.getSemantics(find.byKey(const Key('amount'))),
          labelNode,
        ),
        isFalse,
      );
      handle.dispose();
    });

    testWidgets('the money fields show no placeholder value', (tester) async {
      await openForm(tester, FakeApiClient());
      for (final key in ['amount', 'commission']) {
        expect(
          tester.widget<TextField>(find.byKey(Key(key))).decoration?.hintText,
          isNull,
        );
      }
    });
  });
}
