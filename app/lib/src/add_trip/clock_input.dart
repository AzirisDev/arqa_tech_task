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
