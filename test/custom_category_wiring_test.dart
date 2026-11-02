import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:recurly/models/custom_category.dart';
import 'package:recurly/models/enums.dart';
import 'package:recurly/models/subscription.dart';
import 'package:recurly/providers/category_providers.dart';
import 'package:recurly/services/custom_category_service.dart';
import 'package:recurly/services/database_service.dart';
import 'package:recurly/utils/spend_history.dart';
import 'package:recurly/utils/split_copies.dart';
import 'package:recurly/widgets/category/icon_picker_sheet.dart';

/// BUG-17 (D4: custom categories wired into subscriptions) and BUG-16.
class _FakeCustomCategories extends CustomCategoryNotifier {
  _FakeCustomCategories(List<CustomCategory> categories)
      : super(CustomCategoryService()) {
    state = categories;
  }
}

final homeServices = CustomCategory(
  id: 'cat-home',
  name: 'Home Services',
  icon: '\u{1F3E0}',
);

Subscription _sub(String id, double price, {String? customId}) => Subscription(
      id: id,
      name: id,
      price: price,
      billingCycle: BillingCycle.monthly,
      firstBillDate: DateTime(2026, 10, 5),
      category: customId == null
          ? SubscriptionCategory.entertainment
          : SubscriptionCategory.other,
      createdAt: DateTime(2026, 11, 2),
      customCategoryId: customId,
    );

void main() {
  test('BUG-16: every emoji tile has an emoji, none repeated', () {
    expect(kCategoryEmojis, hasLength(80));
    expect(kCategoryEmojis.where((e) => e.isEmpty), isEmpty);
    expect(kCategoryEmojis.toSet(), hasLength(kCategoryEmojis.length));
  });

  test('customCategoryId survives JSON (sync, backup)', () {
    final sub = _sub('cleaner', 40, customId: 'cat-home');
    final back = Subscription.fromJson(sub.toJson());
    expect(back.customCategoryId, 'cat-home');
    expect(back.category, SubscriptionCategory.other);
    expect(
      back.copyWith(clearCustomCategoryId: true).customCategoryId,
      isNull,
    );
  });

  test('customCategoryId survives Hive (HiveField 24)', () async {
    final dir = await Directory.systemTemp.createTemp('recurly_cat_');
    Hive.init(dir.path);
    DatabaseService.registerAdapters();
    final box = await Hive.openBox<Subscription>('cat_test');
    await box.put('c', _sub('c', 40, customId: 'cat-home'));
    await box.put('d', _sub('d', 10));
    await box.close();
    final reopened = await Hive.openBox<Subscription>('cat_test');
    expect(reopened.get('c')!.customCategoryId, 'cat-home');
    expect(reopened.get('d')!.customCategoryId, isNull);
    await reopened.close();
    await dir.delete(recursive: true);
  });

  group('categoryOfProvider', () {
    ProviderContainer container(List<CustomCategory> customs) =>
        ProviderContainer(
          overrides: [
            customCategoriesProvider
                .overrideWith((ref) => _FakeCustomCategories(customs)),
          ],
        );

    test('custom category when it exists on this device', () {
      final c = container([homeServices]);
      final cat = c.read(categoryOfProvider)(_sub('x', 1, customId: 'cat-home'));
      expect(cat.name, 'Home Services');
      expect(cat.isCustom, isTrue);
      expect(cat.colorIndex, SubscriptionCategory.values.length);
    });

    test('falls back to the built-in when the id is unknown here', () {
      final c = container([]);
      final cat = c.read(categoryOfProvider)(_sub('x', 1, customId: 'cat-home'));
      expect(cat, UnifiedCategory.fromEnum(SubscriptionCategory.other));
    });
  });

  test('Spending over time groups by the custom category', () {
    final custom = UnifiedCategory.fromCustom(homeServices);
    UnifiedCategory categoryOf(Subscription s) => s.customCategoryId != null
        ? custom
        : UnifiedCategory.fromEnum(s.category);
    final history = computeSpendHistory(
      subscriptions: [_sub('cleaner', 40, customId: 'cat-home'), _sub('tv', 10)],
      now: DateTime(2026, 11, 20),
      convert: (a, _) => a,
      months: 1,
      categoryOf: categoryOf,
    );
    expect(history.single.amountFor(custom), 40);
    expect(
      history.single
          .amountFor(UnifiedCategory.fromEnum(SubscriptionCategory.entertainment)),
      10,
    );
  });

  test("a partner's copy doesn't carry the owner's local category id", () {
    final owned = _sub('cleaner', 40, customId: 'cat-home').copyWith(
      ownerUid: 'A',
      splitWith: [
        {'uid': 'B', 'sharePercent': 50, 'accepted': true},
      ],
    );
    final copy = partnerCopyFor(owned, ownerUid: 'A', myUid: 'B')!;
    expect(copy.customCategoryId, isNull);
    expect(copy.category, SubscriptionCategory.other);
  });
}
