import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:recurly/models/enums.dart';
import 'package:recurly/models/subscription.dart';
import 'package:recurly/services/backup_service.dart';
import 'package:recurly/services/budget_service.dart';
import 'package:recurly/services/credit_card_service.dart';
import 'package:recurly/services/custom_category_service.dart';
import 'package:recurly/services/database_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('recurly_backup_');
    Hive.init(tempDir.path);
    DatabaseService.registerAdapters();

    DatabaseService().debugSetSubscriptionsBox(
      await Hive.openBox<Subscription>('backup_test_subscriptions'),
    );
    await CustomCategoryService().initialize();
    await CreditCardService().initialize();
    await BudgetService().initialize();
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  Subscription makeSub(String id, {DateTime? deletedAt}) => Subscription(
        id: id,
        name: 'Sub $id',
        price: 9.99,
        currency: 'USD',
        billingCycle: BillingCycle.monthly,
        firstBillDate: DateTime(2026, 1, 15),
        category: SubscriptionCategory.entertainment,
        createdAt: DateTime(2026, 1, 15),
        deletedAt: deletedAt,
      );

  test('backup → wipe → restore round-trips all data', () async {
    await DatabaseService().addSubscription(makeSub('a'));
    await DatabaseService()
        .addSubscription(makeSub('b', deletedAt: DateTime(2026, 6, 20)));
    final category = await CustomCategoryService()
        .addCategory(name: 'Gaming', icon: '🎮', isEmoji: true);
    final card = await CreditCardService()
        .addCard(name: 'Visa', cutoffDay: 15, dueDay: 5);
    await BudgetService().saveSettings(
      (BudgetService().getSettings())..overallMonthlyBudget = 100,
    );

    final json = BackupService().buildBackupJson();

    // Wipe everything.
    await DatabaseService().deleteAllSubscriptions();
    await CustomCategoryService().deleteCategory(category.id);
    await CreditCardService().deleteCard(card.id);
    await BudgetService().clearAllBudgets();
    expect(DatabaseService().getAllSubscriptions(), isEmpty);

    final result = await withClock(
      Clock.fixed(DateTime(2026, 7, 3, 12)),
      () => BackupService().restoreFromJsonString(json),
    );

    expect(result.subscriptions, 2);
    expect(result.categories, 1);
    expect(result.cards, 1);
    expect(result.budgetRestored, isTrue);
    expect(result.skipped, 0);

    final subs = DatabaseService().getAllSubscriptions();
    expect(subs, hasLength(2));
    final restored = subs.firstWhere((s) => s.id == 'a');
    expect(restored.name, 'Sub a');
    expect(restored.price, 9.99);
    // updatedAt is bumped to restore time so LWW sync keeps restored data.
    expect(restored.updatedAt, DateTime(2026, 7, 3, 12));
    // Soft-deleted subs keep their recently-deleted status.
    expect(subs.firstWhere((s) => s.id == 'b').deletedAt, isNotNull);

    expect(
      CustomCategoryService().getCategoryById(category.id)?.name,
      'Gaming',
    );
    expect(CreditCardService().getCardById(card.id)?.cutoffDay, 15);
    expect(BudgetService().getSettings().overallMonthlyBudget, 100);
  });

  test('restore merges by id without deleting existing data', () async {
    await DatabaseService().deleteAllSubscriptions();
    await DatabaseService().addSubscription(makeSub('keep-me'));

    final backup = jsonEncode({
      'app': 'recurly',
      'formatVersion': 1,
      'subscriptions': [makeSub('from-file').toJson()],
    });
    final result = await BackupService().restoreFromJsonString(backup);

    expect(result.subscriptions, 1);
    final ids = DatabaseService().getAllSubscriptions().map((s) => s.id);
    expect(ids, containsAll(['keep-me', 'from-file']));
  });

  test('invalid entries are skipped, the rest still import', () async {
    await DatabaseService().deleteAllSubscriptions();

    final backup = jsonEncode({
      'app': 'recurly',
      'formatVersion': 1,
      'subscriptions': [
        makeSub('good').toJson(),
        {'id': 'broken'}, // missing required fields
      ],
    });
    final result = await BackupService().restoreFromJsonString(backup);

    expect(result.subscriptions, 1);
    expect(result.skipped, 1);
    expect(DatabaseService().getAllSubscriptions().single.id, 'good');
  });

  test('rejects non-backup files with a readable message', () async {
    expect(
      () => BackupService().restoreFromJsonString('not json at all'),
      throwsFormatException,
    );
    expect(
      () => BackupService()
          .restoreFromJsonString(jsonEncode({'app': 'other', 'x': 1})),
      throwsFormatException,
    );
  });

  test('rejects backups from a newer format version', () async {
    final backup = jsonEncode({
      'app': 'recurly',
      'formatVersion': 999,
      'subscriptions': <Object>[],
    });
    expect(
      () => BackupService().restoreFromJsonString(backup),
      throwsFormatException,
    );
  });
}
