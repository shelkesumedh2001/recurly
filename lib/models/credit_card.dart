import 'package:clock/clock.dart';
import 'package:hive/hive.dart';

import '../utils/card_dates.dart';

part 'credit_card.g.dart';

/// A credit card whose statement cycle the user wants tracked.
///
/// Subscriptions reference a card via `Subscription.cardId`. Cards are
/// local-only (not synced) — a synced sub whose `cardId` doesn't exist on
/// this device simply shows no card info.
@HiveType(typeId: 9)
class CreditCardInfo extends HiveObject {
  CreditCardInfo({
    required this.id,
    required this.name,
    required this.cutoffDay,
    required this.dueDay,
    this.colorHex,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Unique identifier
  @HiveField(0)
  String id;

  /// Display name, e.g. "HDFC Regalia" or "Amex"
  @HiveField(1)
  String name;

  /// Day of month (1–31) the statement closes; clamped in short months.
  @HiveField(2)
  int cutoffDay;

  /// Day of month (1–31) the payment is due; clamped in short months.
  @HiveField(3)
  int dueDay;

  /// Optional accent color in hex format (e.g., '#F4A089')
  @HiveField(4)
  String? colorHex;

  @HiveField(5)
  DateTime createdAt;

  /// When the currently accumulating statement closes (first cutoff after
  /// today). Uses clock.now() so tests can pin the date.
  DateTime get nextCutoffDate => nextOccurrenceOfDay(cutoffDay, clock.now());

  /// When the previous statement closed (most recent cutoff on/before today).
  DateTime get previousCutoffDate =>
      previousOccurrenceOfDay(cutoffDay, clock.now());

  /// The next payment due date (first occurrence of [dueDay] after today).
  /// This is the reminder target — it belongs to the most recently CLOSED
  /// statement, not the one still accumulating.
  DateTime get nextDueDate => nextOccurrenceOfDay(dueDay, clock.now());

  /// The due date of the statement that is still accumulating: the first
  /// occurrence of [dueDay] strictly after that statement closes
  /// ([nextCutoffDate]). Renewals landing on the current statement are
  /// actually paid on this date.
  DateTime get currentStatementDueDate =>
      nextOccurrenceOfDay(dueDay, nextCutoffDate);

  /// True if [date] falls in the currently accumulating statement window:
  /// after the previous cutoff, up to and including the next cutoff.
  bool isInCurrentStatement(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.isAfter(previousCutoffDate) && !d.isAfter(nextCutoffDate);
  }

  CreditCardInfo copyWith({
    String? id,
    String? name,
    int? cutoffDay,
    int? dueDay,
    String? colorHex,
    DateTime? createdAt,
    bool clearColor = false,
  }) {
    return CreditCardInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      cutoffDay: cutoffDay ?? this.cutoffDay,
      dueDay: dueDay ?? this.dueDay,
      colorHex: clearColor ? null : (colorHex ?? this.colorHex),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'CreditCardInfo(id: $id, name: $name, cutoff: $cutoffDay, due: $dueDay)';
}
