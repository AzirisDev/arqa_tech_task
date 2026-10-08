# Digit-only Time Input Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In the add-trip form, the driver types times as digits only and the colon appears automatically (`1023` → `10:23`). Short inputs are accepted: `20` → 20:00, `930` → 09:30.

**Architecture:** A new pure-Dart file `app/lib/src/add_trip/clock_input.dart` holds the parse rules and a `TextInputFormatter`. The form uses them for live formatting, for normalising the field when it loses focus, and for building the timestamp that `trip_core.validateTrip` checks. Server and `trip_core` are unchanged.

**Tech Stack:** Flutter 3.47.2 / Dart 3.13 (fvm), flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-08-time-input-digits-design.md`

## Global Constraints

- Branch `feature/shift-diary`; paths relative to the repository root.
- User-facing strings in Russian; identifiers, comments, commit messages in English. No new user-facing messages: invalid times still produce `Некорректное время начала` / `Некорректное время окончания` via `validateTrip`.
- Validation rules live only in `trip_core`; the app only builds the timestamp string.
- Code must stay `dart format`-clean and `flutter analyze`-clean.
- Commit messages end with a blank line and `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

### Task 1: Digit-only time input

**Files:**
- Create: `app/lib/src/add_trip/clock_input.dart`
- Create: `app/test/clock_input_test.dart`
- Modify: `app/lib/src/add_trip/add_trip_screen.dart` (`_clock` regex at line 29, `_timestamp` at lines 56–64, `_clockField` at lines 137–156)
- Modify: `app/test/add_trip_screen_test.dart` (append 4 tests)
- Modify: `README.md` («Решения» bullet + «Сейчас: …» test-count line)

**Interfaces:**
- Consumes: existing `_AddTripScreenState` members `_clearErrors(List<String>)`, `_saving`, `widget.api.driverOffset`; `formatUtcOffset` from `trip_core`; test helpers in `app/test/add_trip_screen_test.dart`: `day` (`LocalDate(2026, 10, 1)`), `openForm(tester, api)`, `fill(tester, {start, end, amount, commission})` (taps «Карта»), `submit(tester)`; `FakeApiClient` (`savedTrips`) from `app/test/fakes.dart`.
- Produces (`package:shift_diary/src/add_trip/clock_input.dart`):
  - `typedef Clock = ({int hour, int minute});`
  - `Clock? parseClockInput(String text)`
  - `String formatClockDigits(String digits)`
  - `String? formatClockInput(String text)`
  - `class ClockInputFormatter extends TextInputFormatter` with `const ClockInputFormatter()`

- [ ] **Step 1: Write the failing unit tests**

`app/test/clock_input_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_diary/src/add_trip/clock_input.dart';

void main() {
  group('parseClockInput', () {
    test('accepts hour-only, H:MM and HH:MM, with or without a colon', () {
      const cases = {
        '20': (hour: 20, minute: 0),
        '9': (hour: 9, minute: 0),
        '0': (hour: 0, minute: 0),
        '930': (hour: 9, minute: 30),
        '102': (hour: 1, minute: 2),
        '1023': (hour: 10, minute: 23),
        '0810': (hour: 8, minute: 10),
        '2359': (hour: 23, minute: 59),
        '10:23': (hour: 10, minute: 23),
        '9:30': (hour: 9, minute: 30),
      };
      cases.forEach((input, expected) {
        expect(parseClockInput(input), expected, reason: input);
      });
    });

    test('rejects empty, too long, out-of-range and non-digit input', () {
      for (final input in [
        '',
        '12345',
        '2460',
        '24',
        '99',
        '1260',
        '975',
        'ab',
      ]) {
        expect(parseClockInput(input), isNull, reason: input);
      }
    });
  });

  test('formatClockDigits shows the colon where it will be saved', () {
    const cases = {
      '': '',
      '2': '2',
      '20': '20',
      '930': '9:30',
      '102': '1:02',
      '1023': '10:23',
    };
    cases.forEach((digits, expected) {
      expect(formatClockDigits(digits), expected, reason: digits);
    });
  });

  test('formatClockInput normalises to HH:MM or returns null', () {
    expect(formatClockInput('20'), '20:00');
    expect(formatClockInput('930'), '09:30');
    expect(formatClockInput('1023'), '10:23');
    expect(formatClockInput('10:23'), '10:23');
    expect(formatClockInput('2460'), isNull);
  });

  group('ClockInputFormatter', () {
    const formatter = ClockInputFormatter();

    TextEditingValue apply(String oldText, String newText) =>
        formatter.formatEditUpdate(
          TextEditingValue(text: oldText),
          TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          ),
        );

    test('inserts the colon while 1023 is typed digit by digit', () {
      var text = '';
      final shown = <String>[];
      for (final digit in ['1', '0', '2', '3']) {
        text = apply(text, text + digit).text;
        shown.add(text);
      }
      expect(shown, ['1', '10', '1:02', '10:23']);
    });

    test('accepts a pasted time with a colon', () {
      expect(apply('', '10:23').text, '10:23');
    });

    test('drops non-digits', () {
      expect(apply('', '1a2b3').text, '1:23');
    });

    test('ignores a fifth digit', () {
      expect(apply('10:23', '10:235').text, '10:23');
    });

    test('keeps the cursor at the end', () {
      expect(
        apply('10', '102').selection,
        const TextSelection.collapsed(offset: 4),
      );
    });
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `cd app && flutter test test/clock_input_test.dart`
Expected: compilation FAIL — `Error when reading 'lib/src/add_trip/clock_input.dart'`.

- [ ] **Step 3: Implement `clock_input.dart`**

`app/lib/src/add_trip/clock_input.dart`:

```dart
import 'package:flutter/services.dart';

typedef Clock = ({int hour, int minute});

final _digits = RegExp(r'^\d+$');
final _nonDigits = RegExp(r'\D');

/// Reads a time typed as digits, with or without a colon.
///
/// 1–2 digits are an hour (`20` → 20:00), 3 digits are H:MM (`930` → 09:30),
/// 4 digits are HH:MM (`1023` → 10:23). Returns null for anything else and
/// for hours above 23 or minutes above 59.
Clock? parseClockInput(String text) {
  final digits = text.trim().replaceAll(':', '');
  if (!_digits.hasMatch(digits) || digits.length > 4) return null;
  final (hour, minute) = switch (digits.length) {
    1 || 2 => (int.parse(digits), 0),
    3 => (int.parse(digits.substring(0, 1)), int.parse(digits.substring(1))),
    _ => (int.parse(digits.substring(0, 2)), int.parse(digits.substring(2))),
  };
  if (hour > 23 || minute > 59) return null;
  return (hour: hour, minute: minute);
}

/// Live display for up to 4 typed digits; matches what [parseClockInput]
/// will save (`102` → `1:02`, `1023` → `10:23`).
String formatClockDigits(String digits) => switch (digits.length) {
  <= 2 => digits,
  3 => '${digits[0]}:${digits.substring(1)}',
  _ => '${digits.substring(0, 2)}:${digits.substring(2, 4)}',
};

/// `HH:MM` for a valid input (`20` → `20:00`), otherwise null.
String? formatClockInput(String text) {
  final clock = parseClockInput(text);
  if (clock == null) return null;
  return '${_two(clock.hour)}:${_two(clock.minute)}';
}

/// Keeps up to 4 digits and inserts the colon as the driver types.
class ClockInputFormatter extends TextInputFormatter {
  const ClockInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(_nonDigits, '');
    if (digits.length > 4) digits = digits.substring(0, 4);
    final text = formatClockDigits(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

String _two(int value) => value.toString().padLeft(2, '0');
```

- [ ] **Step 4: Run unit tests to verify they pass**

Run: `cd app && flutter test test/clock_input_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Write the failing widget tests**

Append inside `main()` of `app/test/add_trip_screen_test.dart` (after the existing tests):

```dart
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

    await tester.tap(find.byKey(const Key('end-time')));
    await tester.pump();

    expect(find.text('09:30'), findsOneWidget);
  });
```

- [ ] **Step 6: Run to verify failure**

Run: `cd app && flutter test test/add_trip_screen_test.dart`
Expected: the 4 new tests FAIL (e.g. `1023` stays `1023`; `20` is rejected with «Некорректное время начала» so `savedTrips` is empty). The existing tests still pass.

- [ ] **Step 7: Wire it into the form**

In `app/lib/src/add_trip/add_trip_screen.dart`:

Add the import after `import '../format.dart';`:

```dart
import 'clock_input.dart';
```

Delete the line:

```dart
  static final _clock = RegExp(r'^(\d{1,2}):(\d{2})$');
```

Replace `_timestamp` (doc comment included) with:

```dart
  /// ISO-8601 timestamp in the driver offset, or null when [clock] is not a
  /// valid time — `validateTrip` then reports the field.
  String? _timestamp(LocalDate date, String clock) {
    final time = formatClockInput(clock);
    if (time == null) return null;
    return '${date}T$time:00${formatUtcOffset(widget.api.driverOffset)}';
  }
```

Add this method right after `_clearErrors`:

```dart
  /// Shows a valid time as `HH:MM` once the driver leaves the field.
  void _normalizeClock(TextEditingController controller) {
    final normalized = formatClockInput(controller.text);
    if (normalized != null && normalized != controller.text) {
      controller.text = normalized;
    }
  }
```

Replace `_clockField` with:

```dart
  Widget _clockField(
    Key key,
    TextEditingController controller,
    String label,
    String? error,
    List<String> clears,
  ) => Focus(
    skipTraversal: true,
    onFocusChange: (hasFocus) {
      if (!hasFocus) _normalizeClock(controller);
    },
    child: TextField(
      key: key,
      controller: controller,
      enabled: !_saving,
      keyboardType: TextInputType.number,
      onChanged: (_) => _clearErrors(clears),
      inputFormatters: const [ClockInputFormatter()],
      decoration: InputDecoration(
        labelText: label,
        hintText: 'ЧЧ:ММ',
        errorText: error,
        errorMaxLines: 2,
      ),
    ),
  );
```

(`package:flutter/services.dart` stays imported: `_moneyField` still uses `FilteringTextInputFormatter`.)

- [ ] **Step 8: Run the app suite**

Run: `cd app && dart format lib test && flutter test && flutter analyze`
Expected: `All tests passed!` (all previous tests plus the new ones) and `No issues found!`. Record the exact test count.

- [ ] **Step 9: Update README**

In `README.md`, section «Решения», add after the «Точность времени» bullet:

```markdown
- **Ввод времени** — только цифры, двоеточие подставляется само: `1023` → 10:23, `930` → 09:30, `20` → 20:00. Клавиатура цифровая; при выходе из поля время показывается полностью (`ЧЧ:ММ`).
```

In the «Сейчас: …» line, set the app count to the number from Step 8 (trip_core 39 and server 24 are unchanged).

- [ ] **Step 10: Commit**

```bash
git add app/lib/src/add_trip/clock_input.dart app/lib/src/add_trip/add_trip_screen.dart app/test/clock_input_test.dart app/test/add_trip_screen_test.dart README.md
git commit -m "feat(app): type trip times as digits, colon inserted automatically

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
