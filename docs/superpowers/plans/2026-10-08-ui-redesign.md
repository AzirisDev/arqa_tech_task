# UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the Flutter app after the owner's dark mock: a new theme with light and dark palettes, a redesigned day screen and a redesigned add-trip form. Behaviour stays the same.

**Architecture:** One theme file (`buildAppTheme` + `AppColors` ThemeExtension) wired into `MaterialApp` with `ThemeMode.system`. New formatting helpers and a money input formatter. Day-screen and form widgets are rewritten on top of the existing controller and logic.

**Tech Stack:** Flutter 3.47.2 / Dart 3.13 (fvm), Material 3, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-08-ui-redesign-design.md`

## Global Constraints

- Work only in `app/` (plus `README.md` in Task 3). Server and `packages/trip_core` must not change.
- No behaviour change to:
  - validation (only `trip_core.validateTrip`),
  - the retry id,
  - conflict handling («ЗАКРЫТЬ» pops with no result and the day refreshes),
  - digit-only time input (`ClockInputFormatter`, focus normalisation),
  - keyboard dismiss on tap outside,
  - the stale-response guard.
- Widget keys stay exactly as they are: `prev-day`, `next-day`, `pick-day`, `add-trip`, `date`, `start-time`, `end-time`, `ends-next-day`, `amount`, `commission`, `submit`.
- User-facing strings are Russian, exactly as written in this plan. Identifiers and comments are English.
- Existing tests may change only where this plan says so (new strings). Never delete or weaken other assertions.
- Every commit: `cd app && dart format lib test && flutter test && flutter analyze` clean first. Commit messages end with a blank line and `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

### Task 1: Theme, formatting helpers, money input

**Files:**
- Create: `app/lib/src/theme/app_theme.dart`
- Create: `app/lib/src/add_trip/money_input.dart`
- Modify: `app/lib/src/format.dart` (replace whole file)
- Modify: `app/lib/main.dart` (theme wiring)
- Test: `app/test/format_test.dart` (add tests), `app/test/money_input_test.dart`, `app/test/app_theme_test.dart`

**Interfaces:**
- Produces:
  - `class AppColors extends ThemeExtension<AppColors>` with `net`, `cash`, `card`, `surfaceCard`, `inputFill`, `muted` (`Color`), `static const dark`, `static const light`, `static AppColors of(BuildContext)`.
  - `ThemeData buildAppTheme(Brightness brightness)`.
  - `format.dart`: `String groupThousands(String digits)`, `String formatMoney(int)` (unchanged output), `String formatDeduction(int)`, `String formatDayLong(LocalDate)`, `String formatTripCount(int)`, and the still-existing `formatDay`, `formatClock`, `formatDuration`, `formatTripTime`.
  - `money_input.dart`: `class MoneyInputFormatter extends TextInputFormatter` (`const MoneyInputFormatter()`), `int? parseMoneyInput(String text)`.

- [ ] **Step 1: Write failing tests**

Append inside `main()` of `app/test/format_test.dart`:

```dart
  test('formatDayLong: day, short month, year, weekday', () {
    expect(formatDayLong(const LocalDate(2026, 10, 1)), '1 окт. 2026, Чт');
    expect(formatDayLong(const LocalDate(2026, 9, 30)), '30 сент. 2026, Ср');
    expect(formatDayLong(const LocalDate(2026, 5, 4)), '4 мая 2026, Пн');
  });

  test('formatTripCount uses Russian plural forms', () {
    const cases = {
      0: '0 поездок',
      1: '1 поездка',
      2: '2 поездки',
      4: '4 поездки',
      5: '5 поездок',
      11: '11 поездок',
      12: '12 поездок',
      14: '14 поездок',
      21: '21 поездка',
      22: '22 поездки',
      25: '25 поездок',
      111: '111 поездок',
    };
    cases.forEach((count, expected) {
      expect(formatTripCount(count), expected, reason: '$count');
    });
  });

  test('formatDeduction prefixes a minus sign', () {
    expect(formatDeduction(585), '−585 ₸');
  });

  test('groupThousands', () {
    expect(groupThousands(''), '');
    expect(groupThousands('999'), '999');
    expect(groupThousands('2400'), '2 400');
    expect(groupThousands('1234567'), '1 234 567');
  });
```

`app/test/money_input_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_diary/src/add_trip/money_input.dart';

void main() {
  const formatter = MoneyInputFormatter();

  String apply(String text) => formatter
      .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text))
      .text;

  test('groups thousands while typing', () {
    expect(apply('999'), '999');
    expect(apply('2400'), '2 400');
    expect(apply('1234567'), '1 234 567');
  });

  test('keeps digits only and drops leading zeros', () {
    expect(apply('2 4a00'), '2 400');
    expect(apply('0360'), '360');
    expect(apply('0'), '0');
    expect(apply(''), '');
  });

  test('allows at most 9 digits', () {
    expect(apply('1234567890'), '123 456 789');
  });

  test('keeps the cursor at the end', () {
    final value = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '2400'),
    );
    expect(value.selection, const TextSelection.collapsed(offset: 5));
  });

  test('parseMoneyInput reads grouped digits', () {
    expect(parseMoneyInput('2 400'), 2400);
    expect(parseMoneyInput('0'), 0);
    expect(parseMoneyInput(''), isNull);
  });
}
```

`app/test/app_theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_diary/main.dart';
import 'package:shift_diary/src/day/day_screen.dart';
import 'package:shift_diary/src/theme/app_theme.dart';

import 'fakes.dart';

void main() {
  Future<AppColors> colorsFor(WidgetTester tester, Brightness brightness) async {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(ShiftDiaryApp(api: FakeApiClient()));
    await tester.pumpAndSettle();
    return AppColors.of(tester.element(find.byType(DayScreen)));
  }

  testWidgets('uses the dark palette when the system is dark', (tester) async {
    final colors = await colorsFor(tester, Brightness.dark);
    expect(colors.net, AppColors.dark.net);
    expect(colors.surfaceCard, AppColors.dark.surfaceCard);
  });

  testWidgets('uses the light palette when the system is light', (
    tester,
  ) async {
    final colors = await colorsFor(tester, Brightness.light);
    expect(colors.net, AppColors.light.net);
    expect(colors.surfaceCard, AppColors.light.surfaceCard);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `cd app && flutter test test/format_test.dart test/money_input_test.dart test/app_theme_test.dart`
Expected: compilation FAIL (`formatDayLong` not found; `money_input.dart` / `app_theme.dart` missing).

- [ ] **Step 3: Implement**

`app/lib/src/format.dart` (replace the whole file):

```dart
import 'package:trip_core/trip_core.dart';

const _weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
const _months = [
  'янв',
  'фев',
  'мар',
  'апр',
  'мая',
  'июн',
  'июл',
  'авг',
  'сен',
  'окт',
  'ноя',
  'дек',
];
const _weekdaysTitle = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const _monthsShort = [
  'янв.',
  'февр.',
  'мар.',
  'апр.',
  'мая',
  'июн.',
  'июл.',
  'авг.',
  'сент.',
  'окт.',
  'нояб.',
  'дек.',
];
const _nbsp = ' ';

/// Groups digits by thousands with non-breaking spaces: `2 400`.
String groupThousands(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(_nbsp);
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// `2 400 ₸` with non-breaking spaces, so an amount never wraps.
String formatMoney(int amount) =>
    '${amount < 0 ? '-' : ''}${groupThousands(amount.abs().toString())}$_nbsp₸';

/// `−585 ₸` — an amount taken away, such as commission.
String formatDeduction(int amount) => '−${formatMoney(amount)}';

/// `чт, 1 окт`
String formatDay(LocalDate date) =>
    '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}';

/// `1 окт. 2026, Чт`
String formatDayLong(LocalDate date) =>
    '${date.day} ${_monthsShort[date.month - 1]} ${date.year}, '
    '${_weekdaysTitle[date.weekday - 1]}';

/// `1 поездка`, `2 поездки`, `5 поездок`.
String formatTripCount(int count) {
  final lastTwo = count % 100;
  final last = count % 10;
  final word = last == 1 && lastTwo != 11
      ? 'поездка'
      : last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14)
      ? 'поездки'
      : 'поездок';
  return '$count $word';
}

/// `08:10` in driver time.
String formatClock(DateTime instant, Duration offset) {
  final wall = instant.toUtc().add(offset);
  return '${_two(wall.hour)}:${_two(wall.minute)}';
}

/// `22 мин`, `1 ч 35 мин`
String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 60) return '$minutes мин';
  return '${minutes ~/ 60} ч ${_two(minutes % 60)} мин';
}

/// `08:10–08:32 · 22 мин`; `(+1)` marks a trip that ends the next day.
String formatTripTime(Trip trip, Duration offset) {
  final endsNextDay =
      LocalDate.of(trip.end, offset) != LocalDate.of(trip.start, offset);
  final range =
      '${formatClock(trip.start, offset)}–'
      '${formatClock(trip.end, offset)}${endsNextDay ? ' (+1)' : ''}';
  return '$range · ${formatDuration(trip.end.difference(trip.start))}';
}

String _two(int value) => value.toString().padLeft(2, '0');
```

`app/lib/src/add_trip/money_input.dart`:

```dart
import 'package:flutter/services.dart';

import '../format.dart';

const _maxDigits = 9;
final _nonDigits = RegExp(r'\D');
final _leadingZeros = RegExp(r'^0+(?=\d)');

/// Digits only (up to 9), leading zeros dropped, grouped by thousands as the
/// driver types: `2400` → `2 400`.
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text
        .replaceAll(_nonDigits, '')
        .replaceFirst(_leadingZeros, '');
    if (digits.length > _maxDigits) digits = digits.substring(0, _maxDigits);
    final text = groupThousands(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Whole tenge from a grouped input (`2 400` → 2400); null when empty.
int? parseMoneyInput(String text) {
  final digits = text.replaceAll(_nonDigits, '');
  return digits.isEmpty ? null : int.parse(digits);
}
```

`app/lib/src/theme/app_theme.dart`:

```dart
import 'package:flutter/material.dart';

/// App colours that Material's [ColorScheme] has no slot for.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.net,
    required this.cash,
    required this.card,
    required this.surfaceCard,
    required this.inputFill,
    required this.muted,
  });

  /// Take-home amount; also the primary accent.
  final Color net;

  /// Cash payments.
  final Color cash;

  /// Card payments.
  final Color card;

  /// Background of cards.
  final Color surfaceCard;

  /// Background of text inputs and the payment toggle.
  final Color inputFill;

  /// Secondary text.
  final Color muted;

  static const dark = AppColors(
    net: Color(0xFF2BB673),
    cash: Color(0xFFE0A33A),
    card: Color(0xFF3D8BEB),
    surfaceCard: Color(0xFF1F2228),
    inputFill: Color(0xFF181B20),
    muted: Color(0xFF9AA0A8),
  );

  static const light = AppColors(
    net: Color(0xFF1E9E5E),
    cash: Color(0xFFC98512),
    card: Color(0xFF2F74D0),
    surfaceCard: Color(0xFFFFFFFF),
    inputFill: Color(0xFFF7F8FA),
    muted: Color(0xFF5F6670),
  );

  /// Colours of the current theme; light colours when the theme has none
  /// (e.g. a bare `MaterialApp` in widget tests).
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? light;

  @override
  AppColors copyWith({
    Color? net,
    Color? cash,
    Color? card,
    Color? surfaceCard,
    Color? inputFill,
    Color? muted,
  }) => AppColors(
    net: net ?? this.net,
    cash: cash ?? this.cash,
    card: card ?? this.card,
    surfaceCard: surfaceCard ?? this.surfaceCard,
    inputFill: inputFill ?? this.inputFill,
    muted: muted ?? this.muted,
  );

  @override
  AppColors lerp(covariant ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      net: Color.lerp(net, other.net, t)!,
      cash: Color.lerp(cash, other.cash, t)!,
      card: Color.lerp(card, other.card, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}

/// App theme for [brightness]: the mock's dark palette or its light twin.
ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colors = isDark ? AppColors.dark : AppColors.light;
  final background = isDark ? const Color(0xFF14161A) : const Color(0xFFF4F5F7);
  final outline = isDark ? const Color(0xFF2E323A) : const Color(0xFFE1E4E8);
  final text = isDark ? const Color(0xFFECEEF1) : const Color(0xFF15171A);
  final scheme =
      ColorScheme.fromSeed(seedColor: colors.net, brightness: brightness)
          .copyWith(
            primary: colors.net,
            onPrimary: Colors.white,
            surface: background,
            onSurface: text,
            onSurfaceVariant: colors.muted,
            outline: outline,
            outlineVariant: outline,
          );

  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    extensions: [colors],
    appBarTheme: AppBarThemeData(
      backgroundColor: background,
      foregroundColor: text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: colors.surfaceCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isDark ? BorderSide.none : BorderSide(color: outline),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: colors.inputFill,
      border: border(outline),
      enabledBorder: border(outline),
      focusedBorder: border(colors.net, 1.5),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 1.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.net,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.net,
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
    ),
    dividerTheme: DividerThemeData(color: outline),
  );
}
```

`app/lib/main.dart`: add `import 'src/theme/app_theme.dart';` after `import 'src/day/day_screen.dart';`, and in `ShiftDiaryApp.build` replace

```dart
      theme: ThemeData(colorSchemeSeed: Colors.teal),
```

with

```dart
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
```

- [ ] **Step 4: Run tests**

Run: `cd app && dart format lib test && flutter test && flutter analyze`
Expected: all tests pass (existing ones unchanged), `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add app/lib/src/theme/app_theme.dart app/lib/src/add_trip/money_input.dart app/lib/src/format.dart app/lib/main.dart app/test/format_test.dart app/test/money_input_test.dart app/test/app_theme_test.dart
git commit -m "feat(app): add light and dark theme, formatting helpers, money input

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Day screen redesign

**Files:**
- Modify: `app/lib/src/day/summary_card.dart` (replace whole file)
- Create: `app/lib/src/day/trip_card.dart`
- Delete: `app/lib/src/day/trip_tile.dart` (`git rm`)
- Modify: `app/lib/src/day/day_screen.dart` (replace whole file)
- Test: `app/test/day_screen_test.dart`

**Interfaces:**
- Consumes: `AppColors.of`, `formatMoney`, `formatDeduction`, `formatDayLong`, `formatTripCount`, `formatTripTime` (Task 1); `DayController`, `DayLoading`, `DayLoaded`, `DayError`, `DayData`, `AddTripScreen` (existing).
- Produces: `SummaryCard({required DaySummary summary})`, `TripCard({required Trip trip, required Duration offset})`, `PaymentChip({required PaymentMethod payment})`, `DayScreen` (same constructor). Keys `split-cash` and `split-card` on the bar segments.

- [ ] **Step 1: Update and add tests (RED)**

In `app/test/day_screen_test.dart`:

Add the import `import 'package:shift_diary/src/format.dart';` if it is missing (it exists today).

Replace the body of `'opens the latest day and shows its summary and trips'` after `await pumpDay(tester, api);` with:

```dart
    expect(find.text('1 окт. 2026, Чт'), findsOneWidget);
    expect(find.text('НА РУКИ'), findsOneWidget);
    expect(find.text('2 поездки'), findsOneWidget);
    expect(find.text(formatMoney(3315)), findsOneWidget); // net
    expect(find.text('Выручка: ${formatMoney(3900)}'), findsOneWidget);
    expect(find.text('Комиссия: ${formatDeduction(585)}'), findsOneWidget);
    expect(find.text('Наличные: ${formatMoney(1500)}'), findsOneWidget);
    expect(find.text('Карта: ${formatMoney(2400)}'), findsOneWidget);
    expect(find.text('08:10–08:32 · 22 мин'), findsOneWidget);
    expect(find.text('09:05–09:20 · 15 мин'), findsOneWidget);
    expect(find.text('Комиссия: ${formatDeduction(360)}'), findsOneWidget);
```

In `'arrows switch days and refetch'`: `'пт, 2 окт'` → `'2 окт. 2026, Пт'`, `'ср, 30 сен'` → `'30 сент. 2026, Ср'`.
In `'a trip saved from the form appears on its day'`: `'чт, 8 окт'` → `'8 окт. 2026, Чт'`.
In `'closing the form after a conflict refreshes the day'`: `find.text('На руки')` → `find.text('НА РУКИ')`.

Append inside `main()`:

```dart
  testWidgets('split bar sizes cash and card by revenue', (tester) async {
    final api = FakeApiClient(
      days: [oct1],
      dayData: {oct1: dayOf(oct1, sampleTrips())},
    );
    await pumpDay(tester, api);

    final cash = tester.getSize(find.byKey(const Key('split-cash'))).width;
    final card = tester.getSize(find.byKey(const Key('split-card'))).width;
    expect(cash, greaterThan(0));
    expect(cash, lessThan(card)); // 1 500 ₸ cash vs 2 400 ₸ card
  });

  testWidgets('empty day shows a hint and no split segments', (tester) async {
    await pumpDay(tester, FakeApiClient()); // opens today, no trips

    expect(find.text('Нет поездок за этот день'), findsOneWidget);
    expect(find.text('Нажмите +, чтобы добавить'), findsOneWidget);
    expect(find.text('0 поездок'), findsOneWidget);
    expect(find.byKey(const Key('split-cash')), findsNothing);
    expect(find.byKey(const Key('split-card')), findsNothing);
  });
```

Run: `cd app && flutter test test/day_screen_test.dart` → the updated and new tests FAIL (old texts are still rendered).

- [ ] **Step 2: Implement the widgets**

`app/lib/src/day/summary_card.dart` (replace whole file):

```dart
import 'package:flutter/material.dart';
import 'package:trip_core/trip_core.dart';

import '../format.dart';
import '../theme/app_theme.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: colors.muted);
    final legend = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'НА РУКИ',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.muted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Text(formatTripCount(summary.tripCount), style: muted),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              formatMoney(summary.net),
              style: theme.textTheme.displaySmall?.copyWith(
                color: colors.net,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            Text('Выручка: ${formatMoney(summary.revenue)}', style: muted),
            Text(
              'Комиссия: ${formatDeduction(summary.commission)}',
              style: muted,
            ),
            const SizedBox(height: 16),
            _PaymentSplitBar(
              cash: summary.cash.revenue,
              card: summary.card.revenue,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Наличные: ${formatMoney(summary.cash.revenue)}',
                    style: legend?.copyWith(color: colors.cash),
                  ),
                ),
                Text(
                  'Карта: ${formatMoney(summary.card.revenue)}',
                  style: legend?.copyWith(color: colors.card),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Cash vs card share of the day's revenue; a plain track when there is none.
class _PaymentSplitBar extends StatelessWidget {
  const _PaymentSplitBar({required this.cash, required this.card});

  final int cash;
  final int card;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: cash + card == 0
            ? ColoredBox(color: Theme.of(context).colorScheme.outline)
            : Row(
                children: [
                  if (cash > 0)
                    Expanded(
                      flex: cash,
                      child: ColoredBox(
                        key: const Key('split-cash'),
                        color: colors.cash,
                      ),
                    ),
                  if (cash > 0 && card > 0) const SizedBox(width: 3),
                  if (card > 0)
                    Expanded(
                      flex: card,
                      child: ColoredBox(
                        key: const Key('split-card'),
                        color: colors.card,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
```

`app/lib/src/day/trip_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:trip_core/trip_core.dart';

import '../format.dart';
import '../theme/app_theme.dart';

class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip, required this.offset});

  final Trip trip;
  final Duration offset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatTripTime(trip, offset),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.muted,
                    ),
                  ),
                ),
                PaymentChip(payment: trip.payment),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              formatMoney(trip.amount),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Комиссия: ${formatDeduction(trip.commission)}',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Наличные» (orange) or «Карта» (blue) pill.
class PaymentChip extends StatelessWidget {
  const PaymentChip({super.key, required this.payment});

  final PaymentMethod payment;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isCash = payment == PaymentMethod.cash;
    final color = isCash ? colors.cash : colors.card;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          isCash ? 'Наличные' : 'Карта',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
```

Run: `git rm app/lib/src/day/trip_tile.dart`

`app/lib/src/day/day_screen.dart` (replace whole file):

```dart
import 'package:flutter/material.dart';
import 'package:trip_core/trip_core.dart';

import '../add_trip/add_trip_screen.dart';
import '../api/api_client.dart';
import '../format.dart';
import '../theme/app_theme.dart';
import 'day_controller.dart';
import 'summary_card.dart';
import 'trip_card.dart';

class DayScreen extends StatefulWidget {
  const DayScreen({super.key, required this.api, this.today});

  final ApiClient api;

  /// Clock for tests; defaults to the current driver-local date.
  final LocalDate Function()? today;

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  late final DayController _controller;

  Duration get _offset => widget.api.driverOffset;

  @override
  void initState() {
    super.initState();
    _controller = DayController(
      api: widget.api,
      today: widget.today ?? () => LocalDate.of(DateTime.now(), _offset),
    );
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final current = _controller.date;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _controller.select(LocalDate(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _addTrip() async {
    final saved = await Navigator.of(context).push<Trip>(
      MaterialPageRoute(
        builder: (_) =>
            AddTripScreen(api: widget.api, initialDate: _controller.date),
      ),
    );
    if (!mounted) return;
    if (saved != null) {
      _controller.select(LocalDate.of(saved.start, _offset));
    } else {
      _controller.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                date: _controller.date,
                onPrevious: _controller.previous,
                onNext: _controller.next,
                onPickDate: _pickDate,
              ),
              Expanded(
                child: switch (_controller.state) {
                  DayLoading() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  DayError(:final message) => _ErrorView(
                    message: message,
                    onRetry: () => _controller.select(_controller.date),
                  ),
                  DayLoaded(:final data) => RefreshIndicator(
                    onRefresh: _controller.refresh,
                    child: _DayContent(data: data, offset: _offset),
                  ),
                },
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          key: const Key('add-trip'),
          tooltip: 'Добавить поездку',
          onPressed: _addTrip,
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.date,
    required this.onPrevious,
    required this.onNext,
    required this.onPickDate,
  });

  final LocalDate date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Дневник смен',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _SquareIconButton(
                key: const Key('prev-day'),
                icon: Icons.chevron_left,
                tooltip: 'Предыдущий день',
                onPressed: onPrevious,
              ),
              Expanded(
                child: TextButton(
                  key: const Key('pick-day'),
                  onPressed: onPickDate,
                  child: Text(
                    formatDayLong(date),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              _SquareIconButton(
                key: const Key('next-day'),
                icon: Icons.chevron_right,
                tooltip: 'Следующий день',
                onPressed: onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}

class _DayContent extends StatelessWidget {
  const _DayContent({required this.data, required this.offset});

  final DayData data;
  final Duration offset;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 104), // room for the FAB
      children: [
        SummaryCard(summary: data.summary),
        const SizedBox(height: 24),
        Text(
          'Поездки за день',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (data.trips.isEmpty)
          const _EmptyDay()
        else
          for (final trip in data.trips)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TripCard(trip: trip, offset: offset),
            ),
      ],
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(
          children: [
            Icon(Icons.directions_car_outlined, size: 32, color: colors.muted),
            const SizedBox(height: 8),
            Text('Нет поездок за этот день', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Нажмите +, чтобы добавить',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: AppColors.of(context).muted,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Run tests**

Run: `cd app && dart format lib test && flutter test && flutter analyze`
Expected: all pass, `No issues found!`.

- [ ] **Step 4: Commit**

```bash
git add -A app/lib/src/day app/test/day_screen_test.dart
git commit -m "feat(app): redesign the day screen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Add-trip form redesign

**Files:**
- Modify: `app/lib/src/add_trip/add_trip_screen.dart` (replace whole file)
- Modify: `app/lib/src/format.dart` (remove `formatDay`, `_weekdays`, `_months`)
- Test: `app/test/add_trip_screen_test.dart`, `app/test/format_test.dart`
- Modify: `README.md` («Сейчас: …» app test count)

**Interfaces:**
- Consumes: `AppColors.of`, `formatDayLong`, `MoneyInputFormatter`, `parseMoneyInput` (Task 1); `ClockInputFormatter`, `formatClockInput` (`clock_input.dart`, existing); `ApiClient`, `ValidationFailure`, `ConflictFailure`, `ApiFailure` (existing).
- Produces: `AddTripScreen` (same constructor and pop contract).

- [ ] **Step 1: Update and add tests (RED)**

In `app/test/add_trip_screen_test.dart`:
- `find.text('Повторить')` → `find.text('ПОВТОРИТЬ')` (retry test).
- `find.text('Закрыть')` → `find.text('ЗАКРЫТЬ')` (conflict test).
- In `'leaving a time field shows the normalised time'`, insert `await tester.ensureVisible(find.byKey(const Key('end-time')));` right before `await tester.tap(find.byKey(const Key('end-time')));` (the redesigned form is taller).

Append inside `main()`:

```dart
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
```

In `app/test/format_test.dart` delete the test `'formatDay uses short Russian weekday and month'` (the function is removed in Step 2; `formatDayLong` is tested instead).

Run: `cd app && flutter test test/add_trip_screen_test.dart` → the changed/new tests FAIL.

- [ ] **Step 2: Implement**

In `app/lib/src/format.dart` delete `_weekdays`, `_months` and the `formatDay` function (with its doc comment).

`app/lib/src/add_trip/add_trip_screen.dart` (replace whole file):

```dart
import 'package:flutter/material.dart';
import 'package:trip_core/trip_core.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../format.dart';
import '../theme/app_theme.dart';
import 'clock_input.dart';
import 'money_input.dart';

class AddTripScreen extends StatefulWidget {
  const AddTripScreen({
    super.key,
    required this.api,
    required this.initialDate,
    this.newId,
  });

  final ApiClient api;
  final LocalDate initialDate;

  /// Trip id generator; defaults to UUID v4. Injected in tests.
  final String Function()? newId;

  @override
  State<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends State<AddTripScreen> {
  static const _fieldKeys = {'start', 'end', 'amount', 'commission', 'payment'};

  // Generated once per screen. Every retry re-sends the same id, so a request
  // that reached the server before the connection dropped is not saved twice.
  late final String _tripId = widget.newId?.call() ?? const Uuid().v4();

  late LocalDate _date = widget.initialDate;
  bool _endsNextDay = false;
  PaymentMethod? _payment;
  final _startTime = TextEditingController();
  final _endTime = TextEditingController();
  final _amount = TextEditingController();
  final _commission = TextEditingController();

  Map<String, String> _errors = const {};
  String? _failure;
  bool _saving = false;
  bool _conflict = false;

  @override
  void dispose() {
    for (final controller in [_startTime, _endTime, _amount, _commission]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// ISO-8601 timestamp in the driver offset, or null when [clock] is not a
  /// valid time — `validateTrip` then reports the field.
  String? _timestamp(LocalDate date, String clock) {
    final time = formatClockInput(clock);
    if (time == null) return null;
    return '${date}T$time:00${formatUtcOffset(widget.api.driverOffset)}';
  }

  Map<String, Object?> _toJson() => {
    'id': _tripId,
    'start': _timestamp(_date, _startTime.text),
    'end': _timestamp(_endsNextDay ? _date.addDays(1) : _date, _endTime.text),
    'amount': parseMoneyInput(_amount.text),
    'commission': parseMoneyInput(_commission.text),
    'payment': _payment?.name,
  };

  /// Drops the errors an edit may have made stale; they are re-checked on submit.
  void _clearErrors(List<String> keys) {
    if (!keys.any(_errors.containsKey)) return;
    setState(
      () => _errors = {
        for (final entry in _errors.entries)
          if (!keys.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  /// Shows a valid time as `HH:MM` once the driver leaves the field.
  void _normalizeClock(TextEditingController controller) {
    final normalized = formatClockInput(controller.text);
    if (normalized != null && normalized != controller.text) {
      controller.text = normalized;
    }
  }

  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  void _selectPayment(PaymentMethod payment) {
    setState(() => _payment = payment);
    _clearErrors(['payment']);
  }

  Future<void> _submit() async {
    switch (validateTrip(_toJson())) {
      case InvalidTrip(:final errors):
        setState(() {
          _errors = errors;
          _failure = null;
        });
      case ValidTrip(:final trip):
        await _save(trip);
    }
  }

  Future<void> _save(Trip trip) async {
    setState(() {
      _errors = const {};
      _failure = null;
      _conflict = false;
      _saving = true;
    });
    try {
      final saved = await widget.api.saveTrip(trip);
      if (mounted) Navigator.of(context).pop(saved);
    } on ValidationFailure catch (failure) {
      if (mounted) setState(() => _errors = failure.errors);
    } on ConflictFailure catch (failure) {
      if (mounted) {
        setState(() {
          _failure = failure.message;
          _conflict = true;
        });
      }
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _failure = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _date = LocalDate(picked.year, picked.month, picked.day));
      _clearErrors(['start', 'end']);
    }
  }

  Widget _clockField(
    Key key,
    TextEditingController controller,
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
      onTapOutside: (_) => _unfocus(),
      inputFormatters: const [ClockInputFormatter()],
      decoration: InputDecoration(
        hintText: 'ЧЧ:ММ',
        prefixIcon: const Icon(Icons.schedule),
        errorText: error,
        errorMaxLines: 2,
      ),
    ),
  );

  Widget _moneyField(
    Key key,
    TextEditingController controller,
    String? error,
    List<String> clears, {
    TextStyle? style,
  }) => TextField(
    key: key,
    controller: controller,
    enabled: !_saving,
    keyboardType: TextInputType.number,
    style: style,
    onChanged: (_) => _clearErrors(clears),
    onTapOutside: (_) => _unfocus(),
    inputFormatters: const [MoneyInputFormatter()],
    decoration: InputDecoration(
      hintText: '0',
      errorText: error,
      errorMaxLines: 2,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorStyle = TextStyle(color: theme.colorScheme.error);
    // Errors without a form field (e.g. `id` or `_` from the server).
    final banner = [
      ?_failure,
      for (final entry in _errors.entries)
        if (!_fieldKeys.contains(entry.key)) entry.value,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Новая поездка')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _FieldLabel('Сумма (₸)'),
                  _moneyField(
                    const Key('amount'),
                    _amount,
                    _errors['amount'],
                    ['amount', 'commission'],
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _FieldLabel('Способ оплаты'),
                  _PaymentToggle(
                    selected: _payment,
                    onSelected: _saving ? null : _selectPayment,
                  ),
                  if (_errors['payment'] case final error?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Text(error, style: errorStyle),
                    ),
                  const SizedBox(height: 20),
                  const _FieldLabel('Дата'),
                  InkWell(
                    key: const Key('date'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: _saving ? null : _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(
                        formatDayLong(_date),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _FieldLabel('Время начала'),
                  _clockField(
                    const Key('start-time'),
                    _startTime,
                    _errors['start'],
                    ['start', 'end'],
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel('Время окончания'),
                  _clockField(
                    const Key('end-time'),
                    _endTime,
                    _errors['end'],
                    ['end'],
                  ),
                  SwitchListTile(
                    key: const Key('ends-next-day'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Закончилась на следующий день'),
                    value: _endsNextDay,
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() => _endsNextDay = value);
                            _clearErrors(['end']);
                          },
                  ),
                  const SizedBox(height: 4),
                  const _FieldLabel('Комиссия (₸)'),
                  _moneyField(
                    const Key('commission'),
                    _commission,
                    _errors['commission'],
                    ['commission'],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final message in banner)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(message, style: errorStyle),
                ),
              FilledButton(
                key: const Key('submit'),
                onPressed: _saving
                    ? null
                    : _conflict
                    ? () => Navigator.of(context).pop()
                    : _submit,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _conflict
                            ? 'ЗАКРЫТЬ'
                            : _failure == null
                            ? 'СОХРАНИТЬ ПОЕЗДКУ'
                            : 'ПОВТОРИТЬ',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: AppColors.of(context).muted),
      ),
    );
  }
}

/// Pill toggle «Карта» / «Наличные»; nothing is selected until the driver
/// picks one.
class _PaymentToggle extends StatelessWidget {
  const _PaymentToggle({required this.selected, required this.onSelected});

  final PaymentMethod? selected;
  final ValueChanged<PaymentMethod>? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final select = onSelected;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.inputFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          _PaymentOption(
            label: 'Карта',
            icon: Icons.credit_card,
            color: colors.card,
            selected: selected == PaymentMethod.card,
            onTap: select == null ? null : () => select(PaymentMethod.card),
          ),
          _PaymentOption(
            label: 'Наличные',
            icon: Icons.payments_outlined,
            color: colors.cash,
            selected: selected == PaymentMethod.cash,
            onTap: select == null ? null : () => select(PaymentMethod.cash),
          ),
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.of(context).muted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? color : Colors.transparent,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: foreground),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Run tests**

Run: `cd app && dart format lib test && flutter test && flutter analyze`
Expected: all pass, `No issues found!`. Record the app test count.

- [ ] **Step 4: README count**

In `README.md`, update the «Сейчас: …» line's app count to the number from Step 3 (trip_core 39, server 24 unchanged).

- [ ] **Step 5: Commit**

```bash
git add app/lib/src/add_trip/add_trip_screen.dart app/lib/src/format.dart app/test/add_trip_screen_test.dart app/test/format_test.dart README.md
git commit -m "feat(app): redesign the add-trip form

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Screenshots (controller, on the iOS simulator)

**Files:**
- Modify: `docs/screenshots/day.png`, `docs/screenshots/add-trip.png`, `docs/screenshots/validation.png`
- Create: `docs/screenshots/day-light.png`
- Modify: `README.md` (screenshot table)

- [ ] **Step 1:** Check `lsof -nP -i :8080`. If a server is already running there, reuse it and do not delete `server/data/trips.db`. Otherwise start `cd server && dart run bin/server.dart` without deleting the DB.
- [ ] **Step 2:** Build `cd app && flutter build ios --simulator --debug`, then launch on the booted simulator. Note the current appearance with `xcrun simctl ui booted appearance`.
- [ ] **Step 3:** With `xcrun simctl ui booted appearance dark`, capture the day screen (2 Oct, with the midnight trip) → `day.png`, the empty-submit form → `validation.png`, and the filled form → `add-trip.png`. Do not save the filled form.
- [ ] **Step 4:** With `xcrun simctl ui booted appearance light`, capture the day screen → `day-light.png`. Restore the appearance noted in Step 2.
- [ ] **Step 5:** README table: add a 4th column «Светлая тема» with `docs/screenshots/day-light.png`. Commit `docs: update screenshots for the redesign`.
