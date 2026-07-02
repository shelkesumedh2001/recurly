/// Pure date math for credit-card statement cutoffs and payment due days.
///
/// A card is configured with a day-of-month (1–31). Months shorter than the
/// configured day clamp to their last day (day 31 → Feb 28/29, Apr 30, …),
/// matching how real card statements behave.
library;

/// Number of days in the given month.
int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// The occurrence of day-of-month [day] in the given [year]/[month],
/// clamped to the month's length.
DateTime occurrenceInMonth(int year, int month, int day) {
  final normalized = DateTime(year, month); // normalizes month overflow
  final clamped = day.clamp(1, daysInMonth(normalized.year, normalized.month));
  return DateTime(normalized.year, normalized.month, clamped);
}

/// Next occurrence of day-of-month [day] strictly AFTER [from] (date-only).
DateTime nextOccurrenceOfDay(int day, DateTime from) {
  final today = DateTime(from.year, from.month, from.day);
  final thisMonth = occurrenceInMonth(today.year, today.month, day);
  if (thisMonth.isAfter(today)) return thisMonth;
  return occurrenceInMonth(today.year, today.month + 1, day);
}

/// Most recent occurrence of day-of-month [day] ON or BEFORE [from]
/// (date-only).
DateTime previousOccurrenceOfDay(int day, DateTime from) {
  final today = DateTime(from.year, from.month, from.day);
  final thisMonth = occurrenceInMonth(today.year, today.month, day);
  if (!thisMonth.isAfter(today)) return thisMonth;
  return occurrenceInMonth(today.year, today.month - 1, day);
}

/// All occurrences of day-of-month [day] strictly after [from], up to and
/// including [to]. Used to project card payment-due dates onto a calendar.
List<DateTime> occurrencesInRange(int day, DateTime from, DateTime to) {
  final dates = <DateTime>[];
  var next = nextOccurrenceOfDay(day, from);
  while (!next.isAfter(to)) {
    dates.add(next);
    next = nextOccurrenceOfDay(day, next);
  }
  return dates;
}
