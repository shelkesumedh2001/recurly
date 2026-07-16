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
      // Non-positive day counts (bad/legacy data) fall back to the 30-day
      // month-equivalent — a zero step would loop bill-date math forever.
      final days = (customDays == null || customDays <= 0) ? 30 : customDays;
      return _addDays(date, days);
  }
}

/// Step [date] back by exactly one [BillingCycle] — the inverse of
/// [addOneCycle], sharing its clamping semantics.
///
/// Used to derive a subscription's stored anchor (`firstBillDate`) from the
/// next bill date the user actually knows: anchoring one cycle back means
/// `nextBillDate` lands exactly on the date they picked, and the current
/// month's budget forecast still sees the charge that already happened.
///
/// Not a perfect inverse where month-length clamping bites: Mar 31 back one
/// month is Feb 28, and forward again is Mar 28. That asymmetry is inherent
/// to calendar months and matches [addOneCycle]'s existing behaviour.
DateTime subtractOneCycle(
  BillingCycle cycle,
  DateTime date, {
  int? customDays,
}) {
  switch (cycle) {
    case BillingCycle.monthly:
      return _addMonths(date, -1);
    case BillingCycle.yearly:
      return _addMonths(date, -12);
    case BillingCycle.weekly:
      return _addDays(date, -7);
    case BillingCycle.custom:
      // Mirrors addOneCycle's guard: a non-positive step would make the
      // anchor meaningless (and hang the projection loops that walk it).
      final days = (customDays == null || customDays <= 0) ? 30 : customDays;
      return _addDays(date, -days);
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
  // Absolute month count, so negative [months] lands in the right year.
  // The old `year + (month + months - 1) ~/ 12` form broke stepping back
  // across January: Dart's `%` returns non-negative, so Jan - 1 produced
  // December of the *same* year. Identical results for positive months.
  final totalMonths = date.year * 12 + (date.month - 1) + months;
  final targetYear = totalMonths ~/ 12;
  final targetMonth = (totalMonths % 12) + 1;
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
