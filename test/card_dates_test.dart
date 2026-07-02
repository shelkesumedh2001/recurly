import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/models/credit_card.dart';
import 'package:recurly/utils/card_dates.dart';

void main() {
  group('nextOccurrenceOfDay', () {
    test('later this month when day is still ahead', () {
      expect(
        nextOccurrenceOfDay(20, DateTime(2026, 7, 15)),
        DateTime(2026, 7, 20),
      );
    });

    test('rolls to next month when day has passed', () {
      expect(
        nextOccurrenceOfDay(10, DateTime(2026, 7, 15)),
        DateTime(2026, 8, 10),
      );
    });

    test('strictly after: same-day rolls to next month', () {
      expect(
        nextOccurrenceOfDay(15, DateTime(2026, 7, 15)),
        DateTime(2026, 8, 15),
      );
    });

    test('day 31 clamps to shorter months', () {
      // Next occurrence of "31" after Apr 1 is Apr 30 (April has 30 days).
      expect(
        nextOccurrenceOfDay(31, DateTime(2026, 4, 1)),
        DateTime(2026, 4, 30),
      );
    });

    test('day 31 clamps to Feb 28 in non-leap years', () {
      expect(
        nextOccurrenceOfDay(31, DateTime(2026, 2, 1)),
        DateTime(2026, 2, 28),
      );
    });

    test('day 31 clamps to Feb 29 in leap years', () {
      expect(
        nextOccurrenceOfDay(31, DateTime(2028, 2, 1)),
        DateTime(2028, 2, 29),
      );
    });

    test('wraps across the year boundary', () {
      expect(
        nextOccurrenceOfDay(5, DateTime(2026, 12, 20)),
        DateTime(2027, 1, 5),
      );
    });
  });

  group('previousOccurrenceOfDay', () {
    test('earlier this month when day already passed', () {
      expect(
        previousOccurrenceOfDay(10, DateTime(2026, 7, 15)),
        DateTime(2026, 7, 10),
      );
    });

    test('on-or-before: same day counts', () {
      expect(
        previousOccurrenceOfDay(15, DateTime(2026, 7, 15)),
        DateTime(2026, 7, 15),
      );
    });

    test('rolls back to previous month when day is ahead', () {
      expect(
        previousOccurrenceOfDay(20, DateTime(2026, 7, 15)),
        DateTime(2026, 6, 20),
      );
    });

    test('wraps back across the year boundary', () {
      expect(
        previousOccurrenceOfDay(28, DateTime(2027, 1, 10)),
        DateTime(2026, 12, 28),
      );
    });
  });

  group('CreditCardInfo statement window', () {
    final card = CreditCardInfo(
      id: 'c1',
      name: 'Test Card',
      cutoffDay: 15,
      dueDay: 5,
      createdAt: DateTime(2026, 1, 1),
    );

    // Fixed "today": July 20 → previous cutoff Jul 15, next cutoff Aug 15,
    // next due date Aug 5.
    final fixed = Clock.fixed(DateTime(2026, 7, 20, 12));

    test('cutoff and due dates derive from the pinned clock', () {
      withClock(fixed, () {
        expect(card.previousCutoffDate, DateTime(2026, 7, 15));
        expect(card.nextCutoffDate, DateTime(2026, 8, 15));
        expect(card.nextDueDate, DateTime(2026, 8, 5));
      });
    });

    test('renewal inside the window lands on the statement', () {
      withClock(fixed, () {
        expect(card.isInCurrentStatement(DateTime(2026, 7, 25)), isTrue);
        // Cutoff day itself is included.
        expect(card.isInCurrentStatement(DateTime(2026, 8, 15)), isTrue);
      });
    });

    test('renewal outside the window does not land on the statement', () {
      withClock(fixed, () {
        // Previous cutoff day belongs to the closed statement.
        expect(card.isInCurrentStatement(DateTime(2026, 7, 15)), isFalse);
        // After next cutoff → next statement.
        expect(card.isInCurrentStatement(DateTime(2026, 8, 16)), isFalse);
      });
    });

    test(
        'currentStatementDueDate is the due date AFTER the accumulating '
        'statement closes (cutoff 15 / due 5 → closes Aug 15, due Sep 5)',
        () {
      withClock(fixed, () {
        expect(card.currentStatementDueDate, DateTime(2026, 9, 5));
        // …while the imminent payment (reminder target) is the closed
        // statement's: due Aug 5.
        expect(card.nextDueDate, DateTime(2026, 8, 5));
      });
    });

    test('same-month due (cutoff 15 / due 25): statement due stays in-month',
        () {
      final sameMonthCard = CreditCardInfo(
        id: 'c2',
        name: 'Same Month',
        cutoffDay: 15,
        dueDay: 25,
        createdAt: DateTime(2026, 1, 1),
      );
      withClock(fixed, () {
        // Today Jul 20: closed statement (Jul 15) is due Jul 25.
        expect(sameMonthCard.nextDueDate, DateTime(2026, 7, 25));
        // Accumulating statement closes Aug 15 → due Aug 25.
        expect(sameMonthCard.currentStatementDueDate, DateTime(2026, 8, 25));
      });
    });

    test('before this month\'s cutoff, the window starts at last month\'s',
        () {
      withClock(Clock.fixed(DateTime(2026, 7, 10)), () {
        expect(card.previousCutoffDate, DateTime(2026, 6, 15));
        expect(card.nextCutoffDate, DateTime(2026, 7, 15));
        // Renewal on Jul 12 lands on the statement closing Jul 15…
        expect(card.isInCurrentStatement(DateTime(2026, 7, 12)), isTrue);
        // …which is due Aug 5.
        expect(card.currentStatementDueDate, DateTime(2026, 8, 5));
      });
    });
  });

  group('occurrencesInRange (calendar projection)', () {
    test('projects one due date per month across the range', () {
      final dates = occurrencesInRange(
        5,
        DateTime(2026, 7, 20),
        DateTime(2026, 10, 20),
      );
      expect(dates, [
        DateTime(2026, 8, 5),
        DateTime(2026, 9, 5),
        DateTime(2026, 10, 5),
      ]);
    });

    test('clamps day 31 per month and never skips February', () {
      final dates = occurrencesInRange(
        31,
        DateTime(2026, 1, 31), // strictly after Jan 31
        DateTime(2026, 4, 30),
      );
      expect(dates, [
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30),
      ]);
    });

    test('empty when the range contains no occurrence', () {
      expect(
        occurrencesInRange(5, DateTime(2026, 7, 6), DateTime(2026, 7, 31)),
        isEmpty,
      );
    });
  });
}
