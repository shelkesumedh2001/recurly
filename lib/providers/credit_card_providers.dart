import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/credit_card.dart';
import '../models/subscription.dart';
import '../services/credit_card_service.dart';
import '../services/notification_service.dart';
import '../utils/money.dart';
import 'currency_providers.dart';
import 'preferences_providers.dart';
import 'subscription_providers.dart';

/// Provider for the credit card service singleton
final creditCardServiceProvider = Provider<CreditCardService>((ref) {
  return CreditCardService();
});

/// State notifier for managing credit cards
class CreditCardNotifier extends StateNotifier<List<CreditCardInfo>> {
  CreditCardNotifier(this._service, this._ref) : super([]) {
    _loadCards();
  }

  final CreditCardService _service;
  final Ref _ref;

  void _loadCards() {
    state = _service.getAllCards();
  }

  /// Fire-and-forget: card-due reminders follow the same renewal reminder
  /// preferences (3-day / 1-day / on-day toggles + time).
  void _rescheduleReminders(CreditCardInfo card) {
    final preferences = _ref.read(preferencesProvider);
    NotificationService().scheduleCardDueNotifications(card, preferences);
  }

  /// Re-schedule renewal reminders of subs assigned to [cardId] so their
  /// "Paid with <card>" suffix reflects a rename/removal immediately.
  void _rescheduleAssignedSubReminders(String cardId) {
    final preferences = _ref.read(preferencesProvider);
    if (!preferences.notificationsEnabled) return;
    final subs = _ref.read(subscriptionProvider).value ?? [];
    for (final sub in subs.where((s) => s.cardId == cardId)) {
      NotificationService().scheduleSubscriptionNotifications(sub, preferences);
    }
  }

  Future<CreditCardInfo> addCard({
    required String name,
    required int cutoffDay,
    required int dueDay,
    String? colorHex,
  }) async {
    final card = await _service.addCard(
      name: name,
      cutoffDay: cutoffDay,
      dueDay: dueDay,
      colorHex: colorHex,
    );
    _loadCards();
    _rescheduleReminders(card);
    return card;
  }

  Future<void> updateCard(CreditCardInfo card) async {
    await _service.updateCard(card);
    _loadCards();
    _rescheduleReminders(card);
    _rescheduleAssignedSubReminders(card.id);
  }

  Future<void> deleteCard(String id) async {
    // Capture assignments before the service clears them.
    final assignedIds = (_ref.read(subscriptionProvider).value ?? [])
        .where((s) => s.cardId == id)
        .map((s) => s.id)
        .toSet();

    await _service.deleteCard(id);
    _loadCards();
    await NotificationService().cancelCardNotifications(id);

    // Card deletion clears cardId on affected subs — refresh their state,
    // then drop the stale "Paid with <card>" suffix from their reminders.
    final subNotifier = _ref.read(subscriptionProvider.notifier);
    await subNotifier.loadSubscriptions();
    final preferences = _ref.read(preferencesProvider);
    if (preferences.notificationsEnabled) {
      final subs = _ref.read(subscriptionProvider).value ?? [];
      for (final sub in subs.where((s) => assignedIds.contains(s.id))) {
        await NotificationService()
            .scheduleSubscriptionNotifications(sub, preferences);
      }
    }
  }
}

/// All tracked credit cards
final creditCardsProvider =
    StateNotifierProvider<CreditCardNotifier, List<CreditCardInfo>>((ref) {
  final service = ref.watch(creditCardServiceProvider);
  return CreditCardNotifier(service, ref);
});

/// Card lookup by id (null-safe: unknown/removed ids return null)
final cardByIdProvider = Provider.family<CreditCardInfo?, String?>((ref, id) {
  if (id == null) return null;
  final cards = ref.watch(creditCardsProvider);
  for (final card in cards) {
    if (card.id == id) return card;
  }
  return null;
});

/// Active subscriptions charged to a card that renew within its currently
/// accumulating statement window (after previous cutoff, up to next cutoff).
final cardStatementSubsProvider =
    Provider.family<List<Subscription>, String>((ref, cardId) {
  final card = ref.watch(cardByIdProvider(cardId));
  if (card == null) return const [];
  final subs = ref.watch(subscriptionProvider).value ?? [];
  return subs
      .where(
        (sub) =>
            sub.cardId == cardId &&
            !sub.isArchived &&
            sub.deletedAt == null &&
            card.isInCurrentStatement(sub.nextBillDate),
      )
      .toList()
    ..sort((a, b) => a.nextBillDate.compareTo(b.nextBillDate));
});

/// Converted total of the card's current-statement renewals, in the
/// display currency (same conversion path as the home hero total).
final cardStatementTotalProvider =
    Provider.family<double, String>((ref, cardId) {
  final subs = ref.watch(cardStatementSubsProvider(cardId));
  final displayCurrency = ref.watch(displayCurrencyProvider);
  final rates = ref.watch(exchangeRatesProvider).value;
  final service = ref.read(currencyServiceProvider);

  double total = 0;
  for (final sub in subs) {
    total += service.convert(
      amount: sub.price,
      from: sub.currency,
      to: displayCurrency,
      rates: rates,
    );
  }
  return roundMoney(total);
});
