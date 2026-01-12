import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import '../models/subscription.dart';
import '../models/app_preferences.dart';
import '../utils/constants.dart';

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

    _initialized = true;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // TODO: Navigate to subscription details when notification is tapped
    // This will be implemented when we add navigation support
    // final subscriptionId = response.payload;
  }

  /// Request notification permission (Android 13+)
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
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
    if (!preferences.notificationsEnabled) return;

    // Cancel existing notifications for this subscription first
    await cancelSubscriptionNotifications(subscription.id);

    final nextBillDate = subscription.nextBillDate;
    final notificationTime = preferences.notificationTime;

    // Schedule 7-day reminder if enabled
    if (preferences.reminder7DaysEnabled) {
      await _scheduleNotification(
        id: _generateNotificationId(subscription.id, 7),
        scheduledDate: _combineDateAndTime(
          nextBillDate.subtract(const Duration(days: 7)),
          notificationTime,
        ),
        title: '${subscription.name} renews in 7 days',
        body:
            'Your ${subscription.formattedPrice} subscription will renew on ${DateFormat.yMMMd().format(nextBillDate)}',
        payload: subscription.id,
      );
    }

    // Schedule 3-day reminder if enabled
    if (preferences.reminder3DaysEnabled) {
      await _scheduleNotification(
        id: _generateNotificationId(subscription.id, 3),
        scheduledDate: _combineDateAndTime(
          nextBillDate.subtract(const Duration(days: 3)),
          notificationTime,
        ),
        title: '${subscription.name} renews in 3 days',
        body:
            'Your ${subscription.formattedPrice} subscription will renew on ${DateFormat.yMMMd().format(nextBillDate)}',
        payload: subscription.id,
      );
    }

    // Schedule 1-day reminder if enabled
    if (preferences.reminder1DayEnabled) {
      await _scheduleNotification(
        id: _generateNotificationId(subscription.id, 1),
        scheduledDate: _combineDateAndTime(
          nextBillDate.subtract(const Duration(days: 1)),
          notificationTime,
        ),
        title: '${subscription.name} renews tomorrow',
        body:
            'Your ${subscription.formattedPrice} subscription will renew on ${DateFormat.yMMMd().format(nextBillDate)}',
        payload: subscription.id,
      );
    }

    // Schedule renewal day reminder if enabled
    if (preferences.reminderOnDayEnabled) {
      await _scheduleNotification(
        id: _generateNotificationId(subscription.id, 0),
        scheduledDate: _combineDateAndTime(
          nextBillDate,
          notificationTime,
        ),
        title: '${subscription.name} renews today',
        body:
            'Your ${subscription.formattedPrice} subscription is renewing today',
        payload: subscription.id,
      );
    }
  }

  /// Schedule a single notification
  Future<void> _scheduleNotification({
    required int id,
    required DateTime scheduledDate,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Don't schedule if date is in the past
    if (scheduledDate.isBefore(DateTime.now())) {
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
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      // Silently fail if scheduling fails (e.g., permission denied)
      // The user will see they don't have permission in the settings screen
    }
  }

  /// Cancel all notifications for a specific subscription
  Future<void> cancelSubscriptionNotifications(String subscriptionId) async {
    if (!_initialized) return;

    try {
      // Cancel all possible notification IDs for this subscription
      await _notifications.cancel(_generateNotificationId(subscriptionId, 7));
      await _notifications.cancel(_generateNotificationId(subscriptionId, 3));
      await _notifications.cancel(_generateNotificationId(subscriptionId, 1));
      await _notifications.cancel(_generateNotificationId(subscriptionId, 0));
    } catch (e) {
      // Silently fail if canceling fails
    }
  }

  /// Reschedule all subscription notifications
  Future<void> rescheduleAllNotifications(
    List<Subscription> subscriptions,
    AppPreferences preferences,
  ) async {
    if (!_initialized) return;

    // Cancel all existing notifications first
    await cancelAllNotifications();

    // Schedule notifications for each active subscription
    for (final subscription in subscriptions) {
      await scheduleSubscriptionNotifications(subscription, preferences);
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    if (!_initialized) return;

    try {
      await _notifications.cancelAll();
    } catch (e) {
      // Silently fail if canceling fails
    }
  }

  /// Generate unique notification ID from subscription ID and days offset
  int _generateNotificationId(String subscriptionId, int daysOffset) {
    // Create a unique ID by combining subscription ID with days offset
    // Using hashCode ensures consistent IDs for the same subscription/offset
    return (subscriptionId + daysOffset.toString()).hashCode;
  }

  /// Combine date and time for scheduling
  DateTime _combineDateAndTime(DateTime date, TimeOfDayPreference time) {
    return DateTime(
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
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      return [];
    }
  }
}
