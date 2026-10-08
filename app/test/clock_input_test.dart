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
