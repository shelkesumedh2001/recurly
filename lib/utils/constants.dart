// App-wide constants
class AppConstants {
  // App Information
  static const String appName = 'Recurly';
  static const String appVersion = '1.0.0';

  // Hive Box Names
  static const String subscriptionsBox = 'subscriptions';
  static const String settingsBox = 'settings';

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
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;

  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 28.0;

  // Card Dimensions
  static const double cardMinHeight = 88.0;
  static const double logoSize = 40.0;

  // Renewal Urgency Thresholds (in days)
  static const int renewalUrgentThreshold = 7;
  static const int renewalWarningThreshold = 14;
}
