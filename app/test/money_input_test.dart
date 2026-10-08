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
