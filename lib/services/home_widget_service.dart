import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../models/subscription.dart';
import '../services/currency_service.dart';
import 'database_service.dart';
import 'preferences_service.dart';

/// Service for managing home screen widgets
class HomeWidgetService {
  HomeWidgetService._();
  static final HomeWidgetService _instance = HomeWidgetService._();
  factory HomeWidgetService() => _instance;

  // Android widget provider name
  static const String _androidWidgetProvider = 'SubscriptionWidgetProvider';

  // iOS widget kind (for future iOS support)
  static const String _iOSWidgetKind = 'SubscriptionWidget';

  // Widget data keys
  static const String _keyTotalSpend = 'total_spend';
  static const String _keyNextRenewalName = 'next_renewal_name';
  static const String _keyNextRenewalDate = 'next_renewal_date';
  static const String _keyNextRenewalPrice = 'next_renewal_price';
  static const String _keySubscriptionCount = 'subscription_count';
  static const String _keyCurrency = 'currency';
  static const String _keyLastUpdated = 'last_updated';

  /// Initialize the home widget service
  Future<void> initialize() async {
    try {
      // Set the app group ID (required for iOS)
      await HomeWidget.setAppGroupId('group.com.recurly.subscriptions');
      debugPrint('HomeWidgetService initialized');
    } catch (e) {
      debugPrint('Failed to initialize HomeWidgetService: $e');
    }
  }

  /// Update widget data with current subscription info
  Future<void> updateWidgetData({String? displayCurrency}) async {
    try {
      final db = DatabaseService();
      final subscriptions = db.getActiveSubscriptions();
      final currencyService = CurrencyService();

      // Get display currency from preferences if not provided
      displayCurrency ??= PreferencesService().getPreferences().displayCurrency;

      // Calculate total monthly spend
      double totalMonthly = 0;
      for (final sub in subscriptions) {
        final converted = currencyService.convert(
          amount: sub.monthlyEquivalent,
          from: sub.currency,
          to: displayCurrency,
          rates: currencyService.getCachedRates(),
        );
        totalMonthly += converted;
      }

      // Find next upcoming renewal
      Subscription? nextRenewal;
      if (subscriptions.isNotEmpty) {
        final sorted = List<Subscription>.from(subscriptions)
          ..sort((a, b) => a.nextBillDate.compareTo(b.nextBillDate));
        nextRenewal = sorted.first;
      }

      // Format currency
      final formattedTotal = currencyService.formatAmount(totalMonthly, displayCurrency);

      // Format next renewal price in display currency
      String nextRenewalPriceFormatted = '';
      if (nextRenewal != null) {
        final convertedPrice = currencyService.convert(
          amount: nextRenewal.price,
          from: nextRenewal.currency,
          to: displayCurrency,
          rates: currencyService.getCachedRates(),
        );
        nextRenewalPriceFormatted = currencyService.formatAmount(convertedPrice, displayCurrency);
      }

      // Save data to widget
      await Future.wait([
        HomeWidget.saveWidgetData(_keyTotalSpend, formattedTotal),
        HomeWidget.saveWidgetData(_keySubscriptionCount, subscriptions.length.toString()),
        HomeWidget.saveWidgetData(_keyCurrency, displayCurrency),
        HomeWidget.saveWidgetData(_keyLastUpdated, DateTime.now().toIso8601String()),
        if (nextRenewal != null) ...[
          HomeWidget.saveWidgetData(_keyNextRenewalName, nextRenewal.name),
          HomeWidget.saveWidgetData(_keyNextRenewalDate, _formatRenewalDate(nextRenewal)),
          HomeWidget.saveWidgetData(_keyNextRenewalPrice, nextRenewalPriceFormatted),
        ] else ...[
          HomeWidget.saveWidgetData(_keyNextRenewalName, 'No subscriptions'),
          HomeWidget.saveWidgetData(_keyNextRenewalDate, ''),
          HomeWidget.saveWidgetData(_keyNextRenewalPrice, ''),
        ],
      ]);

      // Trigger widget update
      await updateWidget();

      debugPrint('Widget data updated: $formattedTotal/month, ${subscriptions.length} subscriptions');
    } catch (e) {
      debugPrint('Failed to update widget data: $e');
    }
  }

  /// Trigger widget UI refresh
  Future<void> updateWidget() async {
    try {
      await HomeWidget.updateWidget(
        androidName: _androidWidgetProvider,
        iOSName: _iOSWidgetKind,
      );
    } catch (e) {
      debugPrint('Failed to update widget: $e');
    }
  }

  /// Format renewal date for display
  String _formatRenewalDate(Subscription subscription) {
    final days = subscription.daysUntilRenewal;
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    if (days < 7) return 'In $days days';

    final date = subscription.nextBillDate;
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  /// Register callback for widget clicks
  Future<void> registerInteractivityCallback(Function(Uri?) callback) async {
    try {
      HomeWidget.widgetClicked.listen(callback);
    } catch (e) {
      debugPrint('Failed to register widget callback: $e');
    }
  }

  /// Get initial URI if app was launched from widget
  Future<Uri?> getInitialUri() async {
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (e) {
      debugPrint('Failed to get initial URI: $e');
      return null;
    }
  }
}
