# Time input without ":" — Design

Date: 2026-10-08
Status: approved
Extends: `2026-10-08-driver-shift-diary-design.md` §7.2 (add-trip screen)

## Goal

In the add-trip form the driver types trip start/end times with digits only. The colon is inserted automatically: `1023` → `10:23`. Short inputs are accepted ("smart" mode).

## Rules

`parseClockInput(String text)` → `({int hour, int minute})?`. All `:` characters are removed first, so a pasted `10:23` behaves like `1023`. Anything other than digits after that → `null`.

| Digits | Meaning | Example |
|---|---|---|
| 1–2 | hour only, minutes 00 | `20` → 20:00, `9` → 09:00, `0` → 00:00 |
| 3 | H:MM | `930` → 09:30, `102` → 01:02 |
| 4 | HH:MM | `1023` → 10:23, `0810` → 08:10 |
| 0 or ≥5 | invalid | `''`, `12345` → `null` |

Hour > 23 or minute > 59 → `null` (`2460`, `99`, `1260`, `975` → `null`). A `null` makes `_timestamp` return `null`, so `trip_core.validateTrip` reports the existing field error («Некорректное время начала» / «…окончания»). No new messages.

`formatClockDigits(String digits)` gives the live display while typing (input is digits only, at most 4):

| Digits | Display |
|---|---|
| 0–2 | as typed: `2`, `20` |
| 3 | `H:MM`: `930` → `9:30`, `102` → `1:02` |
| 4 | `HH:MM`: `1023` → `10:23` |

The live display always matches what `parseClockInput` will save: `1:02` is saved as 01:02, and adding a 4th digit re-splits to `HH:MM`.

`ClockInputFormatter extends TextInputFormatter`: removes every non-digit from the new value, keeps at most the first 4 digits, returns `formatClockDigits(digits)` with the cursor at the end.

`formatClockInput(String text)` → `String?`: the normalised `HH:MM` for a valid input (`20` → `20:00`, `930` → `09:30`), otherwise `null`. It is used when a field loses focus.

## Form changes (`app/lib/src/add_trip/add_trip_screen.dart`)

- Time fields: `keyboardType: TextInputType.number` (the iOS number pad has no `:` key), `inputFormatters: [ClockInputFormatter()]`, hint stays `ЧЧ:ММ`.
- When a time field loses focus and its text is valid, replace the text with the normalised `HH:MM`. Invalid text is left as typed, so the driver can fix it. This does not trigger validation or clear errors by itself. The existing per-field error clearing runs on user edits only and is unchanged.
- `_timestamp(LocalDate date, String clock)` uses `parseClockInput` instead of the old `^(\d{1,2}):(\d{2})$` regex and builds `'${date}T$HH:$MM:00${formatUtcOffset(offset)}'` from the parsed values.
- Server and `trip_core` are not changed.

## Files

- New: `app/lib/src/add_trip/clock_input.dart` (pure Dart + `TextInputFormatter`; no widgets).
- New: `app/test/clock_input_test.dart`.
- Changed: `app/lib/src/add_trip/add_trip_screen.dart`, `app/test/add_trip_screen_test.dart`, `README.md` (one «Решения» bullet + test count).

## Testing

- Unit (`clock_input_test.dart`): every row of both tables above, plus invalid inputs (`''`, `12345`, `2460`, `99`, `1260`, `975`, `ab`), plus `ClockInputFormatter` on: typing `1023` digit by digit, pasting `10:23`, pasting `1a2b3`, and a 5th digit being dropped.
- Widget (`add_trip_screen_test.dart`): typing `1023` into start shows `10:23`; saving with start `20` and end `2130` sends 20:00–21:30; start `930` and end `1000` sends 09:30–10:00; leaving the start field after typing `930` shows `09:30`. Existing tests that type `08:10` keep passing unchanged.
