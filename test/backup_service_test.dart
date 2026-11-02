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

  // P3-5: restoring a household partner's backup used to overwrite the
  // restorer's own sub with the partner's half-price copy of it.
  test("restoring a partner's backup skips their copies and keeps mine",
      () async {
    await DatabaseService().deleteAllSubscriptions();
    const a = 'uidA';
    const b = 'uidB';
    // B's copy of A's Gym (split 50% with B).
    await DatabaseService().addSubscription(
      makeSub('gym').copyWith(price: 25, ownerUid: a),
    );
    // B's own Disney+ at full price, split 50% with A.
    final disney = makeSub('disney').copyWith(
      price: 9.99,
      ownerUid: b,
      splitWith: [
        {'uid': a, 'sharePercent': 50, 'accepted': true},
      ],
    );
    await DatabaseService().addSubscription(disney);

    // A's backup: A's own Gym (split with B) + A's copy of B's Disney+.
    final backup = jsonEncode({
      'app': 'recurly',
      'formatVersion': 1,
      'ownerUid': a,
      'subscriptions': [
        makeSub('gym')
            .copyWith(price: 50, ownerUid: a, splitWith: [
              {'uid': b, 'sharePercent': 50, 'accepted': true},
            ],)
            .toJson(),
        makeSub('disney').copyWith(price: 4.995, ownerUid: b).toJson(),
      ],
    });

    final result =
        await BackupService().restoreFromJsonString(backup, myUid: b);

    expect(result.subscriptions, 0);
    expect(result.partnerCopies, 2);
    final mine = DatabaseService().getSubscriptionById('disney')!;
    expect(mine.price, 9.99, reason: "B's own sub untouched");
    expect(mine.splitWith, isNotEmpty);
    final gym = DatabaseService().getSubscriptionById('gym')!;
    expect(gym.ownerUid, a, reason: "B's copy of A's Gym left alone");
    expect(gym.price, 25);
  });

  test("restoring my old account's backup into a new account re-owns it",
      () async {
    await DatabaseService().deleteAllSubscriptions();
    final backup = jsonEncode({
      'app': 'recurly',
      'formatVersion': 1,
      'ownerUid': 'oldUid',
      'subscriptions': [
        makeSub('gym').copyWith(ownerUid: 'oldUid', splitWith: [
          {'uid': 'exPartner', 'sharePercent': 50, 'accepted': true},
        ],).toJson(),
      ],
    });
    final result =
        await BackupService().restoreFromJsonString(backup, myUid: 'newUid');
    expect(result.subscriptions, 1);
    final gym = DatabaseService().getSubscriptionById('gym')!;
    expect(gym.ownerUid, 'newUid');
    expect(gym.splitWith, isNull);
  });

  test('restoring my own backup keeps my splits and skips copies', () async {
    await DatabaseService().deleteAllSubscriptions();
    final backup = jsonEncode({
      'app': 'recurly',
      'formatVersion': 1,
      // No header (pre-1.0.5 file): the owner is inferred from the subs.
      'subscriptions': [
        makeSub('gym').copyWith(ownerUid: 'uidA', splitWith: [
          {'uid': 'uidB', 'sharePercent': 50, 'accepted': true},
        ],).toJson(),
        makeSub('icloud').copyWith(ownerUid: 'uidA').toJson(),
        makeSub('disney').copyWith(ownerUid: 'uidB').toJson(),
      ],
    });

    final result =
        await BackupService().restoreFromJsonString(backup, myUid: 'uidA');

    expect(result.subscriptions, 2);
    expect(result.partnerCopies, 1);
    expect(DatabaseService().getSubscriptionById('disney'), isNull);
    expect(DatabaseService().getSubscriptionById('gym')!.splitWith,
        isNotEmpty,);
  });

  test('the backup records whose data it is', () async {
    final data =
        jsonDecode(BackupService().buildBackupJson()) as Map<String, dynamic>;
    expect(data.containsKey('ownerUid'), isTrue);
  });
}
