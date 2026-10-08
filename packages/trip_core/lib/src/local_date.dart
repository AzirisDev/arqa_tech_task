/// A calendar date in the driver's time zone, without a time of day.
class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);

  /// Date of [instant] as shown by a clock running at UTC + [offset].
  factory LocalDate.of(DateTime instant, Duration offset) {
    final wall = instant.toUtc().add(offset);
    return LocalDate(wall.year, wall.month, wall.day);
  }

  final int year;
  final int month;
  final int day;

  static final _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// Parses `YYYY-MM-DD`. Returns null for malformed input and for dates
  /// that do not exist, such as `2026-02-30`.
  static LocalDate? tryParse(String input) {
    final match = _pattern.firstMatch(input);
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final check = DateTime.utc(year, month, day);
    if (check.year != year || check.month != month || check.day != day) {
      return null;
    }
    return LocalDate(year, month, day);
  }

  LocalDate addDays(int days) {
    final shifted = DateTime.utc(year, month, day + days);
    return LocalDate(shifted.year, shifted.month, shifted.day);
  }

  /// ISO weekday: 1 = Monday … 7 = Sunday.
  int get weekday => DateTime.utc(year, month, day).weekday;

  @override
  int compareTo(LocalDate other) => toString().compareTo(other.toString());

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${_two(month)}-${_two(day)}';
}

final _offsetPattern = RegExp(r'^([+-])(\d{2}):(\d{2})$');

/// Parses a UTC offset such as `+05:00` or `-03:30`.
Duration parseUtcOffset(String input) {
  final match = _offsetPattern.firstMatch(input);
  if (match == null) {
    throw FormatException('Expected a UTC offset like +05:00', input);
  }
  final magnitude = Duration(
    hours: int.parse(match[2]!),
    minutes: int.parse(match[3]!),
  );
  return match[1] == '-' ? -magnitude : magnitude;
}

/// Formats an offset as `+05:00`.
String formatUtcOffset(Duration offset) {
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  return '$sign${_two(minutes ~/ 60)}:${_two(minutes % 60)}';
}

/// Formats [instant] as ISO-8601 at UTC + [offset] with seconds precision,
/// e.g. `2026-10-01T08:10:00+05:00`.
String formatWithOffset(DateTime instant, Duration offset) {
  final wall = instant.toUtc().add(offset);
  final date = LocalDate(wall.year, wall.month, wall.day);
  return '${date}T${_two(wall.hour)}:${_two(wall.minute)}:${_two(wall.second)}'
      '${formatUtcOffset(offset)}';
}

String _two(int value) => value.toString().padLeft(2, '0');
