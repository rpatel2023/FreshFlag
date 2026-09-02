import 'dart:math' as math;

/// Adds calendar months while keeping the day-of-month when possible.
///
/// If the target month is shorter, the result is clamped to that month's last
/// day. For example, January 31 + 1 month becomes February 28/29 rather than a
/// duration-based date in March.
DateTime addCalendarMonths(DateTime date, int months) {
  final monthIndex = date.year * 12 + (date.month - 1) + months;
  final targetYear = monthIndex ~/ 12;
  final targetMonth = monthIndex % 12 + 1;
  final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
  return DateTime(
    targetYear,
    targetMonth,
    math.min(date.day, lastDay),
  );
}
