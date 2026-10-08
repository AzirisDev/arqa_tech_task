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
