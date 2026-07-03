import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/models/enums.dart';
import 'package:recurly/models/subscription.dart';

Subscription _sub({
  String id = 'sub-1',
  DateTime? updatedAt,
  DateTime? deletedAt,
}) {
  return Subscription(
    id: id,
    name: 'Netflix',
    price: 9.99,
    currency: 'USD',
    billingCycle: BillingCycle.monthly,
    firstBillDate: DateTime(2025, 1, 1),
    category: SubscriptionCategory.other,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );
}

void main() {
  group('soft-delete / restore invariants (bug #2 + N3)', () {
    test('soft-delete sets deletedAt and bumps updatedAt so LWW propagates', () {
      final t0 = DateTime(2026, 1, 1);
      final active = _sub(updatedAt: t0);
      expect(active.deletedAt, isNull);

      final tDelete = DateTime(2026, 6, 1);
      final deleted = active.copyWith(deletedAt: tDelete, updatedAt: tDelete);

      expect(deleted.deletedAt, tDelete);
      expect(deleted.updatedAt, tDelete);
      // The newer updatedAt is what lets the soft-delete win last-write-wins
      // on other devices instead of being reverted to active.
      expect(deleted.updatedAt!.isAfter(active.updatedAt!), isTrue);
    });

    test('restore clears deletedAt and bumps updatedAt above the deleted copy', () {
      final tDelete = DateTime(2026, 6, 1);
      final deleted = _sub(updatedAt: tDelete, deletedAt: tDelete);

      final tRestore = DateTime(2026, 6, 2);
      final restored = deleted.copyWith(clearDeletedAt: true, updatedAt: tRestore);

      expect(restored.deletedAt, isNull);
      expect(restored.updatedAt, tRestore);
      // Restore must out-rank the soft-deleted copy that may still exist on
      // other devices / remote, or the delete would win and re-hide it.
      expect(restored.updatedAt!.isAfter(deleted.updatedAt!), isTrue);
    });

    test('deletedAt filter separates active from recently-deleted', () {
      // Mirrors the `deletedAt == null` guard used by getActiveSubscriptions,
      // convertedTotalSpendProvider, and the household listener filter.
      final active = _sub(id: 'active', updatedAt: DateTime(2026, 1, 1));
      final deleted = _sub(
        id: 'deleted',
        updatedAt: DateTime(2026, 6, 1),
        deletedAt: DateTime(2026, 6, 1),
      );
      final all = [active, deleted];

      expect(all.where((s) => s.deletedAt == null).map((s) => s.id), ['active']);
      expect(all.where((s) => s.deletedAt != null).map((s) => s.id), ['deleted']);
    });
  });
}
