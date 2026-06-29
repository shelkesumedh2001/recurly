import '../models/enums.dart';

/// Advance [date] by exactly one [BillingCycle]. Single source of truth
/// for billing arithmetic — mirrors the semantics users see on their
/// bank statements.
///
/// - Monthly: add one calendar month. If the source day doesn't exist in
///   the target month (Jan 31 → Feb), clamp to the target month's last day.
/// - Yearly: add one calendar year, with the same day-clamp (Feb 29 →
///   Feb 28 on non-leap years).
/// - Weekly: add 7 calendar days via the date constructor. Using
///   `Duration(days: 7)` (168 hours) drifts ±1 h across DST boundaries.
/// - Custom: add `customDays` calendar days. Falls back to a 30-day
///   month-equivalent when `customDays` is null (legacy custom subs
///   created before the field existed).
DateTime addOneCycle(BillingCycle cycle, DateTime date, {int? customDays}) {
  switch (cycle) {
    case BillingCycle.monthly:
      return _addMonths(date, 1);
    case BillingCycle.yearly:
      return _addMonths(date, 12);
    case BillingCycle.weekly:
      return _addDays(date, 7);
    case BillingCycle.custom:
      final days = customDays ?? 30;
      return _addDays(date, days);
  }
}

DateTime _addDays(DateTime date, int days) {
  return DateTime(
    date.year,
    date.month,
    date.day + days,
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}

DateTime _addMonths(DateTime date, int months) {
  final targetYear = date.year + (date.month + months - 1) ~/ 12;
  final targetMonth = ((date.month + months - 1) % 12) + 1;
  final daysInTargetMonth = _daysInMonth(targetYear, targetMonth);
  final clampedDay =
      date.day > daysInTargetMonth ? daysInTargetMonth : date.day;
  return DateTime(
    targetYear,
    targetMonth,
    clampedDay,
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}

int _daysInMonth(int year, int month) {
  const daysPerMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  if (month == 2 && _isLeapYear(year)) return 29;
  return daysPerMonth[month - 1];
}

bool _isLeapYear(int year) {
  if (year % 4 != 0) return false;
  if (year % 100 != 0) return true;
  return year % 400 == 0;
}
