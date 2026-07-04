import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/budget.dart';
import '../models/credit_card.dart';
import '../models/custom_category.dart';
import '../models/subscription.dart';
import '../utils/changelog.dart';
import 'budget_service.dart';
import 'credit_card_service.dart';
import 'custom_category_service.dart';
import 'database_service.dart';

/// What a restore actually imported, for the confirmation toast.
class BackupRestoreResult {
  const BackupRestoreResult({
    required this.subscriptions,
    required this.categories,
    required this.cards,
    required this.budgetRestored,
    required this.skipped,
  });

  final int subscriptions;
  final int categories;
  final int cards;
  final bool budgetRestored;

  /// Entries that failed to parse and were left out (rest still imports).
  final int skipped;

  String get summary {
    final parts = <String>[
      '$subscriptions subscription${subscriptions == 1 ? '' : 's'}',
      if (categories > 0) '$categories categories',
      if (cards > 0) '$cards cards',
      if (budgetRestored) 'budget',
    ];
    final base = 'Restored ${parts.join(', ')}';
    return skipped > 0 ? '$base ($skipped entries skipped)' : base;
  }
}

/// Full-fidelity JSON backup and restore of the user's data:
/// all subscriptions (active, archived, recently deleted), custom
/// categories, credit cards, and budget settings.
///
/// Restore is a MERGE: entries in the file overwrite entries with the same
/// id; nothing that isn't in the file gets deleted. Restored subscriptions
/// get `updatedAt = now` so a signed-in user's next sync pushes the
/// restored data instead of having last-write-wins discard it.
class BackupService {
  factory BackupService() => _instance;
  BackupService._();
  static final BackupService _instance = BackupService._();

  static const int formatVersion = 1;

  /// Refuse absurdly large files before decoding (backup files are KBs).
  static const int _maxFileBytes = 10 * 1024 * 1024;

  /// Build the backup JSON string.
  String buildBackupJson() {
    final now = clock.now();
    final payload = <String, dynamic>{
      'app': 'recurly',
      'formatVersion': formatVersion,
      'exportedAt': now.toIso8601String(),
      'appBuild': kAppBuild,
      'subscriptions': DatabaseService()
          .getAllSubscriptions()
          .map((s) => s.toJson())
          .toList(),
      'customCategories': CustomCategoryService()
          .getAllCustomCategories()
          .map(_categoryToJson)
          .toList(),
      'creditCards':
          CreditCardService().getAllCards().map(_cardToJson).toList(),
      'budget': _budgetToJson(BudgetService().getSettings()),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Write the backup to a temp file and open the system share sheet.
  Future<void> shareBackup() async {
    final json = buildBackupJson();
    final directory = await getTemporaryDirectory();
    final stamp = DateFormat('yyyy-MM-dd').format(clock.now());
    final file = File('${directory.path}/recurly-backup-$stamp.json');
    await file.writeAsString(json);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
    );
  }

  /// Let the user pick a backup file and merge it in.
  ///
  /// Returns null if the picker was cancelled. Throws [FormatException]
  /// with a user-readable message when the file isn't a Recurly backup.
  Future<BackupRestoreResult?> restoreFromFile() async {
    final picked = await FilePicker.pickFiles();
    final path = picked?.files.single.path;
    if (path == null) return null;

    final file = File(path);
    if (await file.length() > _maxFileBytes) {
      throw const FormatException('That file is too large to be a backup.');
    }

    return restoreFromJsonString(await file.readAsString());
  }

  /// Validate and merge a backup JSON string (also the unit-test seam).
  Future<BackupRestoreResult> restoreFromJsonString(String json) async {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException("That file isn't a Recurly backup.");
    }
    if (data['app'] != 'recurly' || data['subscriptions'] is! List) {
      throw const FormatException("That file isn't a Recurly backup.");
    }
    if ((data['formatVersion'] as num? ?? 0) > formatVersion) {
      throw const FormatException(
        'This backup was made by a newer version of Recurly — '
        'update the app to restore it.',
      );
    }

    return _merge(data);
  }

  Future<BackupRestoreResult> _merge(Map<String, dynamic> data) async {
    var skipped = 0;
    final now = clock.now();

    // Subscriptions: upsert by id. Bump updatedAt so LWW sync pushes the
    // restored version instead of resurrecting whatever remote holds.
    var subCount = 0;
    for (final raw in data['subscriptions'] as List) {
      try {
        final sub = Subscription.fromJson(raw as Map<String, dynamic>)
            .copyWith(updatedAt: now);
        await DatabaseService().updateSubscription(sub);
        subCount++;
      } catch (_) {
        skipped++;
      }
    }

    var catCount = 0;
    for (final raw in (data['customCategories'] as List?) ?? const []) {
      try {
        await CustomCategoryService()
            .updateCategory(_categoryFromJson(raw as Map<String, dynamic>));
        catCount++;
      } catch (_) {
        skipped++;
      }
    }

    var cardCount = 0;
    for (final raw in (data['creditCards'] as List?) ?? const []) {
      try {
        await CreditCardService()
            .updateCard(_cardFromJson(raw as Map<String, dynamic>));
        cardCount++;
      } catch (_) {
        skipped++;
      }
    }

    var budgetRestored = false;
    final budgetRaw = data['budget'];
    if (budgetRaw is Map<String, dynamic>) {
      try {
        await BudgetService().saveSettings(_budgetFromJson(budgetRaw));
        budgetRestored = true;
      } catch (_) {
        skipped++;
      }
    }

    return BackupRestoreResult(
      subscriptions: subCount,
      categories: catCount,
      cards: cardCount,
      budgetRestored: budgetRestored,
      skipped: skipped,
    );
  }

  // --- per-model JSON (subscription has its own toJson/fromJson) ---

  Map<String, dynamic> _categoryToJson(CustomCategory c) => {
        'id': c.id,
        'name': c.name,
        'icon': c.icon,
        'isEmoji': c.isEmoji,
        'colorHex': c.colorHex,
        'createdAt': c.createdAt.toIso8601String(),
        'sortOrder': c.sortOrder,
      };

  CustomCategory _categoryFromJson(Map<String, dynamic> json) =>
      CustomCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String,
        isEmoji: json['isEmoji'] as bool? ?? true,
        colorHex: json['colorHex'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> _cardToJson(CreditCardInfo c) => {
        'id': c.id,
        'name': c.name,
        'cutoffDay': c.cutoffDay,
        'dueDay': c.dueDay,
        'colorHex': c.colorHex,
        'createdAt': c.createdAt.toIso8601String(),
      };

  CreditCardInfo _cardFromJson(Map<String, dynamic> json) => CreditCardInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        cutoffDay: (json['cutoffDay'] as num).toInt().clamp(1, 31),
        dueDay: (json['dueDay'] as num).toInt().clamp(1, 31),
        colorHex: json['colorHex'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );

  Map<String, dynamic> _budgetToJson(BudgetSettings b) => {
        'overallMonthlyBudget': b.overallMonthlyBudget,
        'budgetAlertsEnabled': b.budgetAlertsEnabled,
        'warningThreshold': b.warningThreshold,
        'categoryBudgets': b.categoryBudgets,
      };

  BudgetSettings _budgetFromJson(Map<String, dynamic> json) => BudgetSettings(
        overallMonthlyBudget: (json['overallMonthlyBudget'] as num?)?.toDouble(),
        budgetAlertsEnabled: json['budgetAlertsEnabled'] as bool? ?? true,
        warningThreshold:
            ((json['warningThreshold'] as num?)?.toDouble() ?? 0.75)
                .clamp(0.1, 1.0),
        categoryBudgets: (json['categoryBudgets'] as Map?)?.map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ),
      );
}
