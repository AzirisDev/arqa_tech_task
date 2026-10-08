# Driver Shift Diary — Design

Date: 2026-10-08
Status: approved in brainstorming, pending written-spec review

## 1. Goal

Mobile app «Дневник смен водителя» (driver shift diary) backed by a small API.

Required (from the assignment):

1. Server returns, for a selected day, the list of trips and a day summary: trip count, revenue, commission, take-home («на руки»), cash/card breakdown.
2. Client shows the day summary and trip list and lets the user switch days.
3. Adding a trip via API with validation (amount > 0, end later than start). Re-sending the same trip must not create a duplicate.
4. Tests for summary calculation and duplicate protection.

Deliverables: public GitHub repo (`AzirisDev/arqa_tech_task`) with README (how to run, what is done), screenshots, short note on AI usage (where it helped, where it was wrong, what was fixed by hand).

In scope beyond minimum: add-trip form in the app.
Out of scope: CI, Docker, overlap detection between trips, editing/deleting trips, auth, multiple drivers.

## 2. Stack

- Backend: Dart, `shelf` + `shelf_router`, SQLite via `sqlite3` package.
- Client: Flutter (iOS + Android), `http`, `intl`, `uuid`. State via plain `ChangeNotifier` — no state-management library.
- Shared: pure-Dart package `trip_core` used by both server and app.
- Tests: `package:test` (core, server), `flutter_test` (app).
- Toolchain on dev machine: Flutter 3.47.2 (via fvm), Dart SDK bundled.

## 3. Repository layout

Dart pub workspace at repo root:

```
arqa_tech_task/
  pubspec.yaml                 # workspace root: packages/trip_core, server, app
  packages/trip_core/
    lib/trip_core.dart
    lib/src/trip.dart          # Trip, PaymentMethod
    lib/src/validation.dart    # validateTrip(json) -> TripValidationResult
    lib/src/summary.dart       # DaySummary, PaymentBreakdown, summarize(trips)
    lib/src/local_date.dart    # LocalDate, localDateOf(instant, offset)
    test/
  server/
    bin/server.dart            # entrypoint: config, open DB, seed, serve
    lib/src/api.dart           # shelf Router -> Handler
    lib/src/trip_repository.dart
    lib/src/seed.dart
    data/trips.json            # seed data
    test/
  app/
    lib/main.dart
    lib/src/api/api_client.dart
    lib/src/day/day_controller.dart
    lib/src/day/day_screen.dart
    lib/src/add_trip/add_trip_screen.dart
    lib/src/format.dart        # money / time formatting
    test/
  docs/
  README.md
```

Principle: validation rules and summary math live only in `trip_core`. Server enforces them; app reuses the same validator for instant form feedback.

## 4. Domain rules (`trip_core`)

### 4.1 Trip

Fields: `id` (String), `start` (DateTime instant), `end` (DateTime instant), `amount` (int), `payment` (`cash` | `card`), `commission` (int).

- Money is integer tenge (₸). No floating point anywhere.
- `start`/`end` are kept as UTC instants internally. JSON output serialises them as ISO-8601 in the driver offset (e.g. `2026-10-01T08:10:00+05:00`).
- Equality (used for idempotent replay) compares instants, not strings: `08:10+05:00` equals `03:10Z`.

### 4.2 Validation — `validateTrip(Map<String, dynamic> json)`

Returns either a `Trip` or a map `field -> message`. Collects all errors, not only the first. Unknown fields are ignored.

| Field | Rule |
|---|---|
| `id` | required, non-empty string, ≤ 64 chars |
| `start`, `end` | required, ISO-8601 string with explicit offset (`+05:00`) or `Z`. Strings without offset are rejected as ambiguous (Dart `DateTime.parse` would silently treat them as local time — must be checked explicitly). |
| `end` | strictly after `start` (checked only if both parse) |
| `amount` | required, integer, > 0 |
| `commission` | required, integer, `0 ≤ commission ≤ amount` |
| `payment` | required, one of `cash`, `card` |

A JSON number with a fractional part (e.g. `2400.5`) is not an integer and is rejected. `2400.0` is also rejected to keep the rule simple: money must be sent as a JSON integer.

### 4.3 Driver-local day

- Driver UTC offset is configuration (`DRIVER_UTC_OFFSET`, default `+05:00`). One driver, one offset.
- A trip belongs to the local date of its `start` in the driver offset: `localDate = (start.toUtc() + offset).date`.
- A trip crossing midnight counts on the day it started.
- A trip submitted with a different offset (e.g. `Z`) still lands on the correct driver-local day.

### 4.4 Summary — `summarize(List<Trip> trips) -> DaySummary`

```
DaySummary {
  tripCount, revenue, commission, net,
  cash: PaymentBreakdown { count, revenue, commission },
  card: PaymentBreakdown { count, revenue, commission },
}
```

- `revenue = Σ amount`, `commission = Σ commission`, `net («на руки») = revenue − commission`.
- Empty list → all zeros.
- Pure function: no I/O, no clock, no filtering — caller passes trips of one day.

## 5. API (server)

Base: `http://<host>:8080`. JSON everywhere (`content-type: application/json; charset=utf-8`).

| Method | Path | Success | Notes |
|---|---|---|---|
| GET | `/api/days` | `200 [{ "date": "2026-10-01", "tripCount": 2 }, ...]` | Days that have trips, ascending. App uses the last one as the initial day. |
| GET | `/api/days/{YYYY-MM-DD}` | `200 { "date", "summary", "trips": [...] }` | Trips sorted by `start`. A day with no trips returns `200` with zero summary and empty list. |
| POST | `/api/trips` | `201` new trip / `200` replay | Body = trip JSON. Response body = stored trip. |

Errors:

| Case | Status | Body |
|---|---|---|
| Validation failed | 400 | `{ "errors": { "<field>": "<message>" } }` |
| Malformed JSON / body not an object | 400 | `{ "errors": { "_": "<message>" } }` |
| Bad date in path | 400 | `{ "errors": { "date": "<message>" } }` |
| Same `id`, different data | 409 | `{ "error": "conflict", "message": "...", "existing": <trip> }` |
| Unknown route | 404 | `{ "error": "not_found" }` |
| Unexpected | 500 | `{ "error": "internal" }` + server log |

### 5.1 Idempotency

Idempotency key = client-provided `id`.

- New `id` → insert → `201`.
- Same `id`, equal trip (per §4.1 equality) → no write → `200` with stored trip.
- Same `id`, different trip → no write → `409`.

Atomicity: `INSERT INTO trips ... ON CONFLICT(id) DO NOTHING`, then check affected rows. If 0, load existing row and compare. The `PRIMARY KEY` guarantees no duplicate row regardless of concurrency; there is no check-then-insert window.

## 6. Storage

SQLite file (default `server/data/trips.db`, configurable via `DB_PATH`; tests use `:memory:`).

```sql
CREATE TABLE IF NOT EXISTS trips (
  id          TEXT PRIMARY KEY,
  start_utc   TEXT NOT NULL,      -- ISO-8601 UTC
  end_utc     TEXT NOT NULL,
  local_date  TEXT NOT NULL,      -- YYYY-MM-DD in driver offset
  amount      INTEGER NOT NULL CHECK (amount > 0),
  commission  INTEGER NOT NULL CHECK (commission >= 0 AND commission <= amount),
  payment     TEXT NOT NULL CHECK (payment IN ('cash','card'))
);
CREATE INDEX IF NOT EXISTS trips_local_date ON trips(local_date, start_utc);
```

`local_date` is computed on insert from the configured offset. (Changing the offset later would require recomputing — acceptable for one driver, noted in README.)

Seed: on startup, if `trips` is empty, import `SEED_PATH` (default `server/data/trips.json`) through `validateTrip`. Invalid rows are logged and skipped; server still starts. Seed file is expanded beyond the assignment sample to 3–4 days, including a trip crossing midnight and a cash-only day.

Config (env vars): `PORT` (8080), `DB_PATH`, `SEED_PATH`, `DRIVER_UTC_OFFSET` (`+05:00`). Default `DB_PATH`/`SEED_PATH` resolve relative to the `server/` package directory (derived from `Platform.script`), not the current working directory, so the server starts correctly from repo root or from `server/`.

## 7. Flutter app

UI language: Russian. Currency: ₸, formatted with `intl` (`2 400 ₸`).

### 7.1 Day screen

- AppBar: `‹  ср, 1 окт  ›`. Arrows step ±1 calendar day; tapping the title opens `showDatePicker`.
- Initial day: last entry of `GET /api/days`; if empty or request fails → today.
- Summary card: headline «На руки» (net); row: «Поездки», «Выручка», «Комиссия»; cash vs card split («Наличные», «Карта») each with count and revenue.
- Trip list rows: `08:10–08:32 · 22 мин`, amount, payment icon, commission in secondary text.
- States: loading, empty («Нет поездок за этот день»), error with «Повторить». Pull-to-refresh.
- Stale-response guard: `DayController` tags each load with the requested date and drops responses that no longer match the selected date.
- FAB `+` → add-trip screen, prefilled with the selected day.

### 7.2 Add-trip screen

- Fields: start date + time, end date + time (end date defaults to start date, editable for trips past midnight), amount, commission, payment (`SegmentedButton`: Наличные / Карта).
- On submit: run `trip_core.validateTrip` locally → show inline errors. Server `400` errors are mapped onto the same fields.
- Trip `id` = UUID v4 generated once in `initState`, reused for every submit attempt from this screen.
- Network failure → message + «Повторить» → resend with same `id`. `201` and `200` both mean success.
- `409` → message that a trip with this id was already saved with different values.
- Submit button disabled while a request is in flight.
- On success: pop with the saved trip; Day screen switches to that trip's local day and reloads.

### 7.3 Plumbing

- `ApiClient` over `package:http`, injectable for tests. Base URL from `--dart-define=API_URL`; defaults: Android emulator `http://10.0.2.2:8080`, otherwise `http://localhost:8080`.
- Typed failures: `ValidationFailure(errors)`, `ConflictFailure`, `NetworkFailure`, `ServerFailure`.
- Platform config for local HTTP: iOS `NSAppTransportSecurity` → `NSAllowsLocalNetworking`; Android `usesCleartextTraffic="true"` (debug).

## 8. Testing

| Package | Tests |
|---|---|
| `trip_core` | `summarize`: empty → zeros; assignment sample → count 2, revenue 3900, commission 585, net 3315, cash 1/1500/225, card 1/2400/360; all-cash day. `localDateOf`: `00:30+05:00` stays same local day; `Z` input converted; midnight-crossing trip on start day. `validateTrip`: each rule, multiple errors at once, missing offset rejected, fractional amount rejected. |
| `server` | Repository on `:memory:` SQLite: new → created; repeat → replay, row count 1; same id + different body → conflict, original unchanged; same instant in other offset → replay. Handler called directly (no socket): `POST` 201/200/409/400 shapes; 20 parallel identical POSTs → exactly one row and exactly one `201`; `GET /api/days/{date}` filters by local day and returns correct summary; bad date → 400; seed skips invalid rows. |
| `app` | Widget tests with fake `ApiClient`: summary and list render; arrows refetch other day; empty and error states; form shows validation errors; retry after network failure reuses the same `id`. |

Note for README: `sqlite3` is synchronous and the server runs in one isolate, so the parallel-POST test mainly guards against regressions; the actual guarantee is the `PRIMARY KEY` + `ON CONFLICT`, which holds even if the code becomes async.

## 9. README contents

- What it is, screenshots.
- How to run: server (`dart run server/bin/server.dart`), app (`flutter run` with `API_URL` note for emulator vs device), tests.
- API reference (short).
- Decisions: driver-local day, integer money, idempotency semantics, offset-required timestamps.
- AI usage: what was generated, where AI was wrong, what was fixed manually (filled in during implementation — keep a running log).
