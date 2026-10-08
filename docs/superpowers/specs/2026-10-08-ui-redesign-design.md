# UI Redesign — Design

Date: 2026-10-08
Status: approved
Reference: dark mobile mock provided by the owner (day screen + «Новая поездка» form). Used as reference, not copied 1:1.
Scope: Flutter app only. Server, `trip_core`, API and app logic (validation, retry id, conflict handling, digit-only time input, keyboard dismiss) are unchanged.

## Decisions

- Theme follows the system: dark palette from the mock plus a matching light palette (`ThemeMode.system`).
- Commission stays a field the driver types (no auto 15%).
- The form keeps the date field and the «Закончилась на следующий день» switch, which the mock does not show, because trips crossing midnight need them.

## Theme (`app/lib/src/theme/app_theme.dart`)

`ThemeData buildAppTheme(Brightness)` plus `AppColors extends ThemeExtension<AppColors>` (`AppColors.of(context)`) for colours Material has no slot for.

| Token | Dark | Light |
|---|---|---|
| background | `#14161A` | `#F4F5F7` |
| card surface | `#1F2228` | `#FFFFFF` |
| outline | `#2E323A` | `#E1E4E8` |
| input fill | `#181B20` | `#F7F8FA` |
| text | `#ECEEF1` | `#15171A` |
| muted text | `#9AA0A8` | `#5F6670` |
| net (green, primary) | `#2BB673` | `#1E9E5E` |
| cash (orange) | `#E0A33A` | `#C98512` |
| card payment (blue) | `#3D8BEB` | `#2F74D0` |

Components: cards have radius 16 and no elevation (light cards get a 1 px outline). Inputs are filled, outlined, radius 12, with the focus border in green. The primary `FilledButton` is green, stadium-shaped, min height 52, bold label. The FAB is a green circle. Money amounts use bold tabular figures.

## Formatting (`app/lib/src/format.dart`)

- `formatDayLong(LocalDate)` → `1 окт. 2026, Чт` (CLDR ru short months: `янв.`, `февр.`, `мар.`, `апр.`, `мая`, `июн.`, `июл.`, `авг.`, `сент.`, `окт.`, `нояб.`, `дек.`). It replaces `formatDay`, which is removed once nothing uses it.
- `formatTripCount(int)` → `1 поездка`, `2 поездки`, `5 поездок`, `11 поездок`, `21 поездка`, `22 поездки`.
- `formatDeduction(int)` → `−585 ₸` (U+2212 minus + `formatMoney`).
- `groupThousands(String digits)` — NBSP grouping, shared by `formatMoney` and the money input.

## Day screen

- No AppBar. The header has the title «Дневник смен». The date row has square outlined ‹ › buttons (keys `prev-day`, `next-day`) and a tappable centre date `formatDayLong` (key `pick-day`, opens the date picker).
- Summary card:
  - «НА РУКИ» label with `formatTripCount` on the right.
  - Net amount, large, green.
  - «Выручка: 3 900 ₸» and «Комиссия: −585 ₸» in muted text.
  - Cash/card split bar sized by revenue (keys `split-cash`, `split-card`; a grey track when both are 0).
  - Legend «Наличные: 1 500 ₸» in orange and «Карта: 2 400 ₸» in blue.
- Section title «Поездки за день». Each trip is a `TripCard`: time line `formatTripTime` (muted), a payment chip («Наличные» orange / «Карта» blue, tinted background), the amount large, and «Комиссия: −360 ₸».
- Empty day: a card with «Нет поездок за этот день» and «Нажмите +, чтобы добавить».
- Error: an icon, the message, and «Повторить».
- FAB: a circular «+» (key `add-trip`, tooltip «Добавить поездку»).

## Add-trip form

- AppBar title «Новая поездка». One card with labelled fields, labels above the inputs, in this order:
  1. «Сумма (₸)» — large input with a `MoneyInputFormatter` (digits only, up to 9, leading zeros dropped, grouped `2 400`). The value is parsed with `parseMoneyInput`.
  2. «Способ оплаты» — pill toggle «Карта» (blue when selected) / «Наличные» (orange when selected). No default.
  3. «Дата» — field with a calendar icon showing `formatDayLong`, opens the date picker (key `date`).
  4. «Время начала» and «Время окончания» — clock icon, existing digit-only behaviour.
  5. «Закончилась на следующий день» switch.
  6. «Комиссия (₸)» — money input, normal size.
- Bottom: the error banner, then a green full-width button «СОХРАНИТЬ ПОЕЗДКУ», which reads «ПОВТОРИТЬ» after a failure and «ЗАКРЫТЬ» after a conflict.
- Widget keys are unchanged.

## Testing

- Unit tests: `formatDayLong`, `formatTripCount` (0, 1, 2, 4, 5, 11, 12, 14, 21, 22, 25, 111), `formatDeduction`, `groupThousands`, `MoneyInputFormatter`, `parseMoneyInput`.
- Widget tests:
  - Existing tests are updated for the new strings.
  - New: the summary shows the trip count, revenue and commission lines, and the legend.
  - New: the split bar's cash segment is narrower than the card segment for the sample day.
  - New: the amount input shows `2 400` and saves 2400.
  - New: the app uses `AppColors.dark` when the platform is dark and `AppColors.light` otherwise.
- Screenshots (iOS simulator): dark day, add-trip and validation screens, plus a light day screen; README table updated.
