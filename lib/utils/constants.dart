// App-wide constants
class AppConstants {
  // App Information
  static const String appName = 'Recurly';
  static const String appVersion = '1.0.0';

  // Hive Box Names
  static const String subscriptionsBox = 'subscriptions';
  static const String settingsBox = 'settings';

  // Notification Settings (Phase 3)
  static const String notificationChannelId = 'subscription_reminders_v2';
  static const String notificationChannelName = 'Subscription Reminders';
  static const String notificationChannelDescription =
      'Reminders for upcoming subscription renewals';
  static const int defaultNotificationHour = 9;
  static const int defaultNotificationMinute = 0;

  // Limits
  static const int freeSubscriptionLimit = 5;

  // Pricing
  static const double proYearlyPrice = 39.99;
  static const String proPriceDisplay = '\$39.99';

  // Animation Durations
  static const Duration standardAnimationDuration = Duration(milliseconds: 350);
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  // Spacing (8dp grid system)
  static const double spacing4 = 4;
  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing20 = 20;
  static const double spacing24 = 24;
  static const double spacing32 = 32;
  static const double spacing48 = 48;

  // Border Radius
  static const double radiusSmall = 8;
  static const double radiusMedium = 16;
  static const double radiusLarge = 28;

  // Card Dimensions
  static const double cardMinHeight = 88;
  static const double logoSize = 40;

  // Renewal Urgency Thresholds (in days)
  static const int renewalUrgentThreshold = 7;
  static const int renewalWarningThreshold = 14;
}
