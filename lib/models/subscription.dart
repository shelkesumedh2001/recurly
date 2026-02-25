import 'package:hive/hive.dart';
import 'enums.dart';

part 'subscription.g.dart';

@HiveType(typeId: 0)
class Subscription extends HiveObject { // For recently deleted feature

  Subscription({
    required this.id,
    required this.name,
    required this.price,
    this.currency = 'USD',
    required this.billingCycle,
    required this.firstBillDate,
    required this.category,
    this.logoUrl,
    this.color,
    this.notes,
    this.isArchived = false,
    required this.createdAt,
    this.sharedWith,
    this.deletedAt,
    this.isFreeTrial = false,
    this.trialEndDate,
    this.priceAfterTrial,
    this.updatedAt,
    this.ownerUid,
    this.householdVisible = true,
    this.splitWith,
    this.priceHistory,
  });

  /// Create from JSON (Firebase)
  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      billingCycle: BillingCycle.values.firstWhere(
        (e) => e.name == json['billingCycle'],
      ),
      firstBillDate: DateTime.parse(json['firstBillDate'] as String),
      category: SubscriptionCategory.values.firstWhere(
        (e) => e.categoryName == json['category'],
      ),
      logoUrl: json['logoUrl'] as String?,
      color: json['color'] as String?,
      notes: json['notes'] as String?,
      isArchived: json['isArchived'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      sharedWith: (json['sharedWith'] as List<dynamic>?)?.cast<String>(),
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
      isFreeTrial: json['isFreeTrial'] as bool? ?? false,
      trialEndDate: json['trialEndDate'] != null
          ? DateTime.parse(json['trialEndDate'] as String)
          : null,
      priceAfterTrial: json['priceAfterTrial'] != null
          ? (json['priceAfterTrial'] as num).toDouble()
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      ownerUid: json['ownerUid'] as String?,
      householdVisible: json['householdVisible'] as bool? ?? true,
      splitWith: (json['splitWith'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      priceHistory: (json['priceHistory'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double price;

  @HiveField(3)
  String currency;

  @HiveField(4)
  BillingCycle billingCycle;

  @HiveField(5)
  DateTime firstBillDate;

  @HiveField(6)
  SubscriptionCategory category;

  @HiveField(7)
  String? logoUrl;

  @HiveField(8)
  String? color;

  @HiveField(9)
  String? notes;

  @HiveField(10)
  bool isArchived;

  @HiveField(11)
  DateTime createdAt;

  @HiveField(12)
  List<String>? sharedWith;

  @HiveField(13)
  DateTime? deletedAt;

  // Phase 5.5: Free Trial Tracker fields
  @HiveField(14)
  bool isFreeTrial;

  @HiveField(15)
  DateTime? trialEndDate;

  @HiveField(16)
  double? priceAfterTrial;

  @HiveField(17)
  DateTime? updatedAt;

  // Phase 5: Cloud sync & household fields
  @HiveField(18)
  String? ownerUid;

  @HiveField(19)
  bool householdVisible;

  @HiveField(20)
  List<Map<String, dynamic>>? splitWith;

  @HiveField(21)
  List<Map<String, dynamic>>? priceHistory;

  /// Whether this subscription has any recorded price changes
  bool get hasPriceHistory => priceHistory != null && priceHistory!.isNotEmpty;

  /// The most recent price change entry, or null
  Map<String, dynamic>? get lastPriceChange =>
      hasPriceHistory ? priceHistory!.last : null;

  /// The amount of the last price change (current price minus last recorded price)
  double get lastPriceChangeAmount {
    if (!hasPriceHistory) return 0.0;
    final oldPrice = (lastPriceChange!['price'] as num).toDouble();
    return price - oldPrice;
  }

  /// The percentage of the last price change
  double get lastPriceChangePercent {
    if (!hasPriceHistory) return 0.0;
    final oldPrice = (lastPriceChange!['price'] as num).toDouble();
    if (oldPrice == 0) return 0.0;
    return ((price - oldPrice) / oldPrice) * 100;
  }

  /// Calculate the next bill date based on billing cycle
  DateTime get nextBillDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var nextDate = DateTime(firstBillDate.year, firstBillDate.month, firstBillDate.day);

    // If start date is in the future, return it directly
    if (nextDate.isAfter(today)) {
      return nextDate;
    }

    // Keep adding billing cycles until we're in the future.
    // The firstBillDate represents when the subscription started (initial payment),
    // so the NEXT renewal is always at least one billing cycle after that.
    // If firstBillDate is today, the next renewal is one cycle from now.
    while (!nextDate.isAfter(today)) {
      nextDate = _addBillingCycle(nextDate);
    }

    return nextDate;
  }

  /// Helper method to add one billing cycle to a date
  DateTime _addBillingCycle(DateTime date) {
    switch (billingCycle) {
      case BillingCycle.monthly:
        return DateTime(
          date.year,
          date.month + 1,
          date.day,
        );
      case BillingCycle.yearly:
        return DateTime(
          date.year + 1,
          date.month,
          date.day,
        );
      case BillingCycle.weekly:
        return date.add(const Duration(days: 7));
      case BillingCycle.custom:
        return DateTime(
          date.year,
          date.month + 1,
          date.day,
        );
    }
  }

  /// Days until the next renewal
  int get daysUntilRenewal {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final next = DateTime(nextBillDate.year, nextBillDate.month, nextBillDate.day);
    return next.difference(today).inDays;
  }

  /// Convert price to monthly equivalent for comparison
  double get monthlyEquivalent {
    return price * billingCycle.getMonthlyMultiplier();
  }

  /// Get renewal urgency status for color coding
  RenewalUrgency get renewalUrgency {
    final days = daysUntilRenewal;
    if (days < 7) return RenewalUrgency.urgent;
    if (days < 14) return RenewalUrgency.warning;
    return RenewalUrgency.normal;
  }

  /// Currency symbol helper
  String get currencySymbol {
    switch (currency) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'INR':
        return '₹';
      default:
        return '\$';
    }
  }

  /// Formatted price string
  String get formattedPrice {
    return '$currencySymbol${price.toStringAsFixed(2)}';
  }

  /// Convert to JSON for Firebase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'currency': currency,
      'billingCycle': billingCycle.name,
      'firstBillDate': firstBillDate.toIso8601String(),
      'category': category.categoryName,
      'logoUrl': logoUrl,
      'color': color,
      'notes': notes,
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
      'sharedWith': sharedWith,
      'deletedAt': deletedAt?.toIso8601String(),
      'isFreeTrial': isFreeTrial,
      'trialEndDate': trialEndDate?.toIso8601String(),
      'priceAfterTrial': priceAfterTrial,
      'updatedAt': updatedAt?.toIso8601String(),
      'ownerUid': ownerUid,
      'householdVisible': householdVisible,
      'splitWith': splitWith,
      'priceHistory': priceHistory,
    };
  }

  /// Copy with method for updates
  Subscription copyWith({
    String? id,
    String? name,
    double? price,
    String? currency,
    BillingCycle? billingCycle,
    DateTime? firstBillDate,
    SubscriptionCategory? category,
    String? logoUrl,
    String? color,
    String? notes,
    bool? isArchived,
    DateTime? createdAt,
    List<String>? sharedWith,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    bool? isFreeTrial,
    DateTime? trialEndDate,
    double? priceAfterTrial,
    bool clearTrialEndDate = false,
    DateTime? updatedAt,
    String? ownerUid,
    bool? householdVisible,
    List<Map<String, dynamic>>? splitWith,
    bool clearSplitWith = false,
    List<Map<String, dynamic>>? priceHistory,
    bool clearPriceHistory = false,
  }) {
    return Subscription(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      billingCycle: billingCycle ?? this.billingCycle,
      firstBillDate: firstBillDate ?? this.firstBillDate,
      category: category ?? this.category,
      logoUrl: logoUrl ?? this.logoUrl,
      color: color ?? this.color,
      notes: notes ?? this.notes,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      sharedWith: sharedWith ?? this.sharedWith,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      isFreeTrial: isFreeTrial ?? this.isFreeTrial,
      trialEndDate: clearTrialEndDate ? null : (trialEndDate ?? this.trialEndDate),
      priceAfterTrial: priceAfterTrial ?? this.priceAfterTrial,
      updatedAt: updatedAt ?? this.updatedAt,
      ownerUid: ownerUid ?? this.ownerUid,
      householdVisible: householdVisible ?? this.householdVisible,
      splitWith: clearSplitWith ? null : (splitWith ?? this.splitWith),
      priceHistory: clearPriceHistory ? null : (priceHistory ?? this.priceHistory),
    );
  }

  /// Days until trial ends (for free trials)
  int get daysUntilTrialEnds {
    if (!isFreeTrial || trialEndDate == null) return -1;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(trialEndDate!.year, trialEndDate!.month, trialEndDate!.day);
    return end.difference(today).inDays;
  }

  /// Check if trial has expired
  bool get isTrialExpired {
    if (!isFreeTrial || trialEndDate == null) return false;
    return DateTime.now().isAfter(trialEndDate!);
  }

  /// Get trial status text
  String get trialStatusText {
    if (!isFreeTrial) return '';
    if (trialEndDate == null) return 'Free Trial';

    final days = daysUntilTrialEnds;
    if (days < 0) return 'Trial Expired';
    if (days == 0) return 'Trial ends today';
    if (days == 1) return 'Trial ends tomorrow';
    return 'Trial ends in $days days';
  }
}

/// Renewal urgency for color coding
enum RenewalUrgency {
  urgent, // < 7 days
  warning, // 7-14 days
  normal, // > 14 days
}
