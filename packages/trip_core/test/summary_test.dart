import 'dart:convert';

import 'package:test/test.dart';
import 'package:trip_core/trip_core.dart';

Trip trip(String id, int amount, PaymentMethod payment, int commission) => Trip(
  id: id,
  start: DateTime.utc(2026, 10, 1, 3),
  end: DateTime.utc(2026, 10, 1, 3, 30),
  amount: amount,
  payment: payment,
  commission: commission,
);

void main() {
  test('empty day is all zeros', () {
    final summary = summarize(const <Trip>[]);
    expect(
      summary,
      const DaySummary(
        tripCount: 0,
        revenue: 0,
        commission: 0,
        cash: PaymentBreakdown.zero,
        card: PaymentBreakdown.zero,
      ),
    );
    expect(summary.net, 0);
  });

  test(
    'assignment sample: revenue, commission, take-home, cash/card split',
    () {
      final summary = summarize([
        trip('t1', 2400, PaymentMethod.card, 360),
        trip('t2', 1500, PaymentMethod.cash, 225),
      ]);
      expect(summary.tripCount, 2);
      expect(summary.revenue, 3900);
      expect(summary.commission, 585);
      expect(summary.net, 3315);
      expect(
        summary.cash,
        const PaymentBreakdown(count: 1, revenue: 1500, commission: 225),
      );
      expect(
        summary.card,
        const PaymentBreakdown(count: 1, revenue: 2400, commission: 360),
      );
    },
  );

  test('all-cash day leaves card breakdown empty', () {
    final summary = summarize([
      trip('a', 1700, PaymentMethod.cash, 255),
      trip('b', 1400, PaymentMethod.cash, 210),
    ]);
    expect(
      summary.cash,
      const PaymentBreakdown(count: 2, revenue: 3100, commission: 465),
    );
    expect(summary.card, PaymentBreakdown.zero);
    expect(summary.net, 2635);
  });

  test('zero-commission trip goes fully to take-home', () {
    final summary = summarize([trip('a', 1000, PaymentMethod.card, 0)]);
    expect(summary.net, 1000);
  });

  test('JSON includes net and round-trips', () {
    final summary = summarize([
      trip('t1', 2400, PaymentMethod.card, 360),
      trip('t2', 1500, PaymentMethod.cash, 225),
    ]);
    final json = summary.toJson();
    expect(json, {
      'tripCount': 2,
      'revenue': 3900,
      'commission': 585,
      'net': 3315,
      'cash': {'count': 1, 'revenue': 1500, 'commission': 225},
      'card': {'count': 1, 'revenue': 2400, 'commission': 360},
    });
    final decoded = jsonDecode(jsonEncode(json)) as Map<String, Object?>;
    expect(DaySummary.fromJson(decoded), summary);
  });
}
