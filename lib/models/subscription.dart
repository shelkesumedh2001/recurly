import 'package:hive/hive.dart';
import 'enums.dart';

part 'subscription.g.dart';

@HiveType(typeId: 0)
class Subscription extends HiveObject {
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
  DateTime? deletedAt; // For recently deleted feature

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
  });

  /// Calculate the next bill date based on billing cycle
  DateTime get nextBillDate {
    final now = DateTime.now();
    var nextDate = firstBillDate;

    // Keep adding billing cycles until we're in the future
    while (nextDate.isBefore(now)) {
      switch (billingCycle) {
        case BillingCycle.monthly:
          nextDate = DateTime(
            nextDate.year,
            nextDate.month + 1,
            nextDate.day,
          );
          break;
        case BillingCycle.yearly:
          nextDate = DateTime(
            nextDate.year + 1,
            nextDate.month,
            nextDate.day,
          );
          break;
        case BillingCycle.weekly:
          nextDate = nextDate.add(const Duration(days: 7));
          break;
        case BillingCycle.custom:
          nextDate = DateTime(
            nextDate.year,
            nextDate.month + 1,
            nextDate.day,
          );
          break;
      }
    }

    return nextDate;
  }

  /// Days until the next renewal
  int get daysUntilRenewal {
    final now = DateTime.now();
    final difference = nextBillDate.difference(now);
    return difference.inDays;
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
      'category': category.name,
      'logoUrl': logoUrl,
      'color': color,
      'notes': notes,
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
      'sharedWith': sharedWith,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

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
        (e) => e.name == json['category'],
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
    );
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
    );
  }
}

/// Renewal urgency for color coding
enum RenewalUrgency {
  urgent, // < 7 days
  warning, // 7-14 days
  normal, // > 14 days
}
