import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/app_preferences.dart';
import '../models/credit_card.dart';
import '../models/subscription.dart';
import '../utils/billing_cycle.dart';
import '../utils/card_dates.dart';
import '../utils/constants.dart';
import 'credit_card_service.dart';

/// Service for managing local notifications
class NotificationService {
  // Singleton pattern
  factory NotificationService() => _instance;
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize notification plugin
  Future<void> initialize() async {
    if (_initialized) return;

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Cold start from a notification: surface its payload the same way a
    // warm tap does, so MainNavigation can route once it's up.
    final launchDetails =
        await _notifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      tappedPayload.value = launchDetails!.notificationResponse?.payload;
    }

    _initialized = true;
    debugPrint('NotificationService: Initialized successfully');
  }

  /// Payload of the most recent notification tap, consumed by
  /// MainNavigation (set to null after routing). Sub reminders carry the
  /// subscription id; card reminders carry 'card:<cardId>'.
  final ValueNotifier<String?> tappedPayload = ValueNotifier(null);

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    tappedPayload.value = response.payload;
  }

  /// Request notification permission (Android 13+)
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      debugPrint('Notification permission status: $status');
      return status.isGranted;
    }
    return true;
  }

  /// Check if notification permission is granted
  Future<bool> hasPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      return status.isGranted;
    }
    return true;
  }

  /// Schedule notifications for a subscription based on preferences
  Future<void> scheduleSubscriptionNotifications(
    Subscription subscription,
    AppPreferences preferences,
  ) async {
    if (!_initialized) {
      throw Exception('NotificationService not initialized');
    }

    // Don't schedule if notifications are disabled
    if (!preferences.notificationsEnabled) {
      debugPrint('Notifications disabled in preferences, skipping scheduling for ${subscription.name}');
      return;
    }

    // Cancel existing notifications for this subscription first
    await cancelSubscriptionNotifications(subscription.id);

    // Look ahead several billing cycles: reminders used to cover only the
    // NEXT bill, so a user who didn't open the app for a while silently
    // stopped getting them (rescheduling only happens at app launch).
    var billDate = subscription.nextBillDate;
    for (var occurrence = 0; occurrence < lookAheadCycles; occurrence++) {
      await _scheduleRenewalReminders(
        subscription,
        preferences,
        billDate,
        occurrence,
      );
      billDate = addOneCycle(
        subscription.billingCycle,
        billDate,
        customDays: subscription.customDays,
      );
    }

    // Trial-end reminders (independent of renewal reminders)
    await _scheduleTrialReminders(subscription, preferences);
  }

  /// How many future billing cycles get reminders scheduled up front.
  static const int lookAheadCycles = 3;

  Future<void> _scheduleRenewalReminders(
    Subscription subscription,
    AppPreferences preferences,
    DateTime billDate,
    int occurrence,
  ) async {
    final notificationTime = preferences.notificationTime;
    // "· Paid with <card>" when the sub is assigned to a tracked card, so
    // the reminder says which card is about to be charged.
    final cardSuffix = _cardSuffix(subscription);
    final billText = DateFormat.yMMMd().format(billDate);

    debugPrint(
        'Scheduling notifications for ${subscription.name} (bill: $billText, occurrence $occurrence)',);

    final offsets = <int>[
      if (preferences.reminder7DaysEnabled) 7,
      if (preferences.reminder3DaysEnabled) 3,
      if (preferences.reminder1DayEnabled) 1,
      if (preferences.reminderOnDayEnabled) 0,
    ];

    for (final daysBefore in offsets) {
      final (title, body) = switch (daysBefore) {
        0 => (
            '${subscription.name} renews today',
            'Your ${subscription.formattedPrice} subscription is renewing today$cardSuffix',
          ),
        1 => (
            '${subscription.name} renews tomorrow',
            'Your ${subscription.formattedPrice} subscription will renew on $billText$cardSuffix',
          ),
        _ => (
            '${subscription.name} renews in $daysBefore days',
            'Your ${subscription.formattedPrice} subscription will renew on $billText$cardSuffix',
          ),
      };
      await _scheduleNotification(
        id: _generateNotificationId(subscription.id, daysBefore, occurrence),
        scheduledDate: _combineDateAndTime(
          billDate.subtract(Duration(days: daysBefore)),
          notificationTime,
        ),
        title: title,
        body: body,
        payload: subscription.id,
      );
    }
  }

  /// Schedule "your free trial ends in N days — cancel before being
  /// charged" reminders. No-op when the sub isn't a trial.
  Future<void> _scheduleTrialReminders(
    Subscription subscription,
    AppPreferences preferences,
  ) async {
    if (!subscription.isFreeTrial || subscription.trialEndDate == null) return;

    final notificationTime = preferences.notificationTime;
    final trialEnd = subscription.trialEndDate!;
    final priceAfter = subscription.priceAfterTrial;
    final amountText = priceAfter != null
        ? '${subscription.currencySymbol}${priceAfter.toStringAsFixed(2)}'
        : 'the recurring price';

    final reminders = <int>[
      if (preferences.trialReminder7DaysEnabled) 7,
      if (preferences.trialReminder3DaysEnabled) 3,
      if (preferences.trialReminder1DayEnabled) 1,
    ];

    for (final daysBefore in reminders) {
      final fireDate = trialEnd.subtract(Duration(days: daysBefore));
      final whenText = daysBefore == 1
          ? 'tomorrow'
          : 'in $daysBefore days';
      await _scheduleNotification(
        id: _generateTrialNotificationId(subscription.id, daysBefore),
        scheduledDate: _combineDateAndTime(fireDate, notificationTime),
        title: '${subscription.name} trial ends $whenText',
        body:
            'Cancel before ${DateFormat.yMMMd().format(trialEnd)} to avoid being charged $amountText.',
        payload: subscription.id,
      );
    }
  }

  /// Schedule payment-due reminders for a credit card. Reuses the renewal
  /// reminder toggles (3-day / 1-day / on-day) and notification time.
  Future<void> scheduleCardDueNotifications(
    CreditCardInfo card,
    AppPreferences preferences,
  ) async {
    if (!_initialized) {
      throw Exception('NotificationService not initialized');
    }
    if (!preferences.notificationsEnabled) return;

    await cancelCardNotifications(card.id);

    final notificationTime = preferences.notificationTime;
    final reminders = <int>[
      if (preferences.reminder3DaysEnabled) 3,
      if (preferences.reminder1DayEnabled) 1,
      if (preferences.reminderOnDayEnabled) 0,
    ];

    // Look ahead: one due date per month, same rationale as renewals.
    var dueDate = card.nextDueDate;
    for (var occurrence = 0; occurrence < lookAheadCycles; occurrence++) {
      final dueText = DateFormat.yMMMd().format(dueDate);
      for (final daysBefore in reminders) {
        final whenText = switch (daysBefore) {
          0 => 'today',
          1 => 'tomorrow',
          _ => 'in $daysBefore days',
        };
        await _scheduleNotification(
          id: _generateCardNotificationId(card.id, daysBefore, occurrence),
          scheduledDate: _combineDateAndTime(
            dueDate.subtract(Duration(days: daysBefore)),
            notificationTime,
          ),
          title: '${card.name} payment due $whenText',
          body: 'Your ${card.name} credit card payment is due on $dueText.',
          payload: 'card:${card.id}',
        );
      }
      dueDate = nextOccurrenceOfDay(card.dueDay, dueDate);
    }
  }

  /// Cancel the payment-due reminders for a credit card
  Future<void> cancelCardNotifications(String cardId) async {
    if (!_initialized) return;

    try {
      for (var occurrence = 0; occurrence < lookAheadCycles; occurrence++) {
        for (final daysBefore in const [3, 1, 0]) {
          await _notifications.cancel(
            _generateCardNotificationId(cardId, daysBefore, occurrence),
          );
        }
      }
      debugPrint('Cancelled card-due notifications for card $cardId');
    } catch (e) {
      debugPrint('Error cancelling card notifications: $e');
    }
  }

  /// Schedule a single notification
  Future<void> _scheduleNotification({
    required int id,
    required tz.TZDateTime scheduledDate,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Don't schedule if date is in the past
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      debugPrint('Notification skipped: Scheduled date $scheduledDate is in the past');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      debugPrint('Zoned scheduling: "$title" at $scheduledDate (ID: $id)');
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('Successfully scheduled: "$title"');
    } catch (e) {
      debugPrint('FAILED to schedule notification: $e');
    }
  }

  /// Cancel all notifications for a specific subscription (renewal + trial)
  Future<void> cancelSubscriptionNotifications(String subscriptionId) async {
    if (!_initialized) return;

    try {
      // Renewal reminders (every offset × every look-ahead occurrence)
      for (var occurrence = 0; occurrence < lookAheadCycles; occurrence++) {
        for (final daysBefore in const [7, 3, 1, 0]) {
          await _notifications.cancel(
            _generateNotificationId(subscriptionId, daysBefore, occurrence),
          );
        }
      }
      // Trial reminders
      await _notifications.cancel(_generateTrialNotificationId(subscriptionId, 7));
      await _notifications.cancel(_generateTrialNotificationId(subscriptionId, 3));
      await _notifications.cancel(_generateTrialNotificationId(subscriptionId, 1));
      debugPrint('Cancelled all notifications for subscription $subscriptionId');
    } catch (e) {
      debugPrint('Error cancelling notifications: $e');
    }
  }

  /// Reschedule all subscription notifications (and card-due reminders,
  /// when [cards] is provided)
  Future<void> rescheduleAllNotifications(
    List<Subscription> subscriptions,
    AppPreferences preferences, {
    List<CreditCardInfo> cards = const [],
  }) async {
    if (!_initialized) return;

    debugPrint('Rescheduling all notifications (${subscriptions.length} subscriptions, ${cards.length} cards)');
    // Cancel all existing notifications first
    await cancelAllNotifications();

    // Schedule notifications for each active subscription
    for (final subscription in subscriptions) {
      await scheduleSubscriptionNotifications(subscription, preferences);
    }

    // Card payment-due reminders
    for (final card in cards) {
      await scheduleCardDueNotifications(card, preferences);
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    if (!_initialized) return;

    try {
      await _notifications.cancelAll();
      debugPrint('All pending notifications cancelled');
    } catch (e) {
      debugPrint('Error cancelling all notifications: $e');
    }
  }

  /// Generate unique notification ID from subscription ID, days offset,
  /// and look-ahead occurrence index. Occurrence 0 keeps the historical
  /// id shape; later occurrences append a '#k' discriminator.
  int _generateNotificationId(
    String subscriptionId,
    int daysOffset, [
    int occurrence = 0,
  ]) {
    final key = occurrence == 0
        ? subscriptionId + daysOffset.toString()
        : '$subscriptionId$daysOffset#$occurrence';
    return key.hashCode;
  }

  /// Generate notification ID for trial-end reminders. Prefixed with
  /// "trial:" so it never collides with renewal reminders for the same
  /// subscription/offset pair.
  int _generateTrialNotificationId(String subscriptionId, int daysOffset) {
    return ('trial:$subscriptionId$daysOffset').hashCode;
  }

  /// Generate notification ID for card payment-due reminders ("card:"
  /// prefix keeps the id space separate from sub/trial reminders).
  int _generateCardNotificationId(
    String cardId,
    int daysOffset, [
    int occurrence = 0,
  ]) {
    final key = occurrence == 0
        ? 'card:$cardId$daysOffset'
        : 'card:$cardId$daysOffset#$occurrence';
    return key.hashCode;
  }

  /// " · Paid with <card>" suffix for renewal reminders, empty when the
  /// sub has no (locally known) card assigned.
  String _cardSuffix(Subscription subscription) {
    if (subscription.cardId == null) return '';
    final card = CreditCardService().getCardById(subscription.cardId);
    return card == null ? '' : ' · Paid with ${card.name}';
  }

  /// Combine date and time for scheduling
  tz.TZDateTime _combineDateAndTime(DateTime date, TimeOfDayPreference time) {
    // Use the configured local location (from main.dart initialization)
    final location = tz.local;
    return tz.TZDateTime(
      location,
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  /// Get pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_initialized) return [];

    try {
      final requests = await _notifications.pendingNotificationRequests();
      debugPrint('Total pending notification requests: ${requests.length}');
      for (final request in requests) {
        debugPrint(' - ID: ${request.id}, Title: ${request.title}');
      }
      return requests;
    } catch (e) {
      debugPrint('Error getting pending notifications: $e');
      return [];
    }
  }

  /// Show an immediate test notification
  Future<void> showTestNotification() async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      await _notifications.show(
        999999, // Specific ID for test
        'Test Notification',
        'If you see this, notifications are working!',
        notificationDetails,
      );
      debugPrint('Test notification sent');
    } catch (e) {
      debugPrint('Failed to send test notification: $e');
    }
  }
}
