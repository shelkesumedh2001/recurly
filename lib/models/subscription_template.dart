import 'enums.dart';

/// Template for popular subscription services
class SubscriptionTemplate {
  final String id;
  final String name;
  final String logoUrl;
  final SubscriptionCategory category;
  final String color; // Hex color
  final double? recommendedPrice; // Can be null for custom pricing
  final BillingCycle defaultBillingCycle;
  final String? description;

  const SubscriptionTemplate({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.category,
    required this.color,
    this.recommendedPrice,
    this.defaultBillingCycle = BillingCycle.monthly,
    this.description,
  });
}

/// Template category for organizing templates
enum TemplateCategory {
  streaming,
  productivity,
  cloudDev;

  String get displayName {
    switch (this) {
      case TemplateCategory.streaming:
        return 'Streaming';
      case TemplateCategory.productivity:
        return 'Productivity';
      case TemplateCategory.cloudDev:
        return 'Cloud & Dev';
    }
  }

  String get icon {
    switch (this) {
      case TemplateCategory.streaming:
        return '🎬';
      case TemplateCategory.productivity:
        return '📊';
      case TemplateCategory.cloudDev:
        return '☁️';
    }
  }
}
