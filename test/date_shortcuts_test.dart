import 'package:flutter_test/flutter_test.dart';
import 'package:freshflag/utils/date_shortcuts.dart';

void main() {
  test('adds calendar months while preserving day when possible', () {
    expect(addCalendarMonths(DateTime(2026, 9, 2), 3), DateTime(2026, 12, 2));
    expect(addCalendarMonths(DateTime(2026, 9, 2), 6), DateTime(2027, 3, 2));
    expect(addCalendarMonths(DateTime(2026, 9, 2), 12), DateTime(2027, 9, 2));
    expect(addCalendarMonths(DateTime(2026, 9, 2), 18), DateTime(2028, 3, 2));
  });

  test('clamps to the last day of a shorter target month', () {
    expect(addCalendarMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    expect(addCalendarMonths(DateTime(2026, 8, 31), 6), DateTime(2027, 2, 28));
    expect(addCalendarMonths(DateTime(2027, 8, 31), 6), DateTime(2028, 2, 29));
  });
}
