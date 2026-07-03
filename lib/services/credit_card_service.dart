import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/credit_card.dart';
import '../utils/constants.dart';
import 'database_service.dart';

/// Service for managing tracked credit cards (local-only, not synced)
class CreditCardService {
  factory CreditCardService() => _instance;
  CreditCardService._internal();
  static final CreditCardService _instance = CreditCardService._internal();

  Box<CreditCardInfo>? _cardsBox;
  final _uuid = const Uuid();

  /// Initialize the service (adapter is registered by DatabaseService)
  Future<void> initialize() async {
    _cardsBox = await Hive.openBox<CreditCardInfo>(AppConstants.creditCardsBox);
  }

  /// All cards, oldest first
  List<CreditCardInfo> getAllCards() {
    if (_cardsBox == null) return [];
    final cards = _cardsBox!.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return cards;
  }

  CreditCardInfo? getCardById(String? id) {
    if (id == null) return null;
    return _cardsBox?.get(id);
  }

  Future<CreditCardInfo> addCard({
    required String name,
    required int cutoffDay,
    required int dueDay,
    String? colorHex,
  }) async {
    final card = CreditCardInfo(
      id: _uuid.v4(),
      name: name.trim(),
      cutoffDay: cutoffDay,
      dueDay: dueDay,
      colorHex: colorHex,
    );
    await _cardsBox?.put(card.id, card);
    return card;
  }

  Future<void> updateCard(CreditCardInfo card) async {
    await _cardsBox?.put(card.id, card);
  }

  /// Delete a card and clear the reference from any subscription that was
  /// assigned to it (keeps sub data consistent; the cleared cardId syncs).
  Future<void> deleteCard(String id) async {
    await _cardsBox?.delete(id);

    final db = DatabaseService();
    for (final sub in db.getAllSubscriptions()) {
      if (sub.cardId == id) {
        await db.updateSubscription(
          sub.copyWith(clearCardId: true, updatedAt: DateTime.now()),
        );
      }
    }
  }
}
