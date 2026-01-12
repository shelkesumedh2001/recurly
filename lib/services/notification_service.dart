import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/app_preferences.dart';
import '../models/subscription.dart';
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
    debugPrint('NotificationService: Initialized successfully');
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // TODO: Navigate to subscription details when notification is tapped
  }

  /// Request notification permission (Android 13+)
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      // Request POST_NOTIFICATIONS
      final status = await Permission.notification.request();
      debugPrint('Notification permission status: $status');
      
      // On Android 13+, also request exact alarm permission if needed
      if (await Permission.scheduleExactAlarm.status.isDenied) {
        debugPrint('Requesting scheduleExactAlarm permission...');
        await Permission.scheduleExactAlarm.request();
      }
      
      return status.isGranted;
    }
    return true;
  }

  /// Check if notification permission is granted
  Future<bool> hasPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      
      // Also check exact alarm permission on Android 13+
      // Permission_handler handles SDK version checks internally
      final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
      // If the permission is restricted (default state) or granted, we consider it valid for our use
      // On < Android 12, this usually returns granted or restricted
      final hasExactAlarm = !exactAlarmStatus.isDenied && !exactAlarmStatus.isPermanentlyDenied;
      
      return status.isGranted && hasExactAlarm;
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

    final nextBillDate = subscription.nextBillDate;
    final notificationTime = preferences.notificationTime;

    debugPrint('Scheduling notifications for ${subscription.name} (Next bill: ${DateFormat.yMMMd().format(nextBillDate)})');

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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('Successfully scheduled: "$title"');
    } catch (e) {
      debugPrint('FAILED to schedule notification: $e');
      
      // If exact alarm fails, try inexact as fallback
      if (e.toString().contains('exact_alarm')) {
        try {
          debugPrint('Retrying with inexact schedule mode...');
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
          debugPrint('Successfully scheduled (inexact fallback): "$title"');
        } catch (e2) {
          debugPrint('Inexact fallback also FAILED: $e2');
        }
      }
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
      debugPrint('Cancelled all notifications for subscription $subscriptionId');
    } catch (e) {
      debugPrint('Error cancelling notifications: $e');
    }
  }

  /// Reschedule all subscription notifications
  Future<void> rescheduleAllNotifications(
    List<Subscription> subscriptions,
    AppPreferences preferences,
  ) async {
    if (!_initialized) return;

    debugPrint('Rescheduling all notifications (${subscriptions.length} subscriptions)');
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
      debugPrint('All pending notifications cancelled');
    } catch (e) {
      debugPrint('Error cancelling all notifications: $e');
    }
  }

  /// Generate unique notification ID from subscription ID and days offset
  int _generateNotificationId(String subscriptionId, int daysOffset) {
    // Create a unique ID by combining subscription ID with days offset
    // Using hashCode ensures consistent IDs for the same subscription/offset
    return (subscriptionId + daysOffset.toString()).hashCode;
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
