/// Split proposal model for subscription splitting
class SplitProposal {
  SplitProposal({
    required this.subId,
    required this.ownerUid,
    required this.partnerUid,
    required this.subscriptionName,
    required this.totalPrice,
    required this.partnerSharePercent,
    this.currency = 'USD',
    this.accepted = false,
    required this.createdAt,
  });

  factory SplitProposal.fromJson(Map<String, dynamic> json) {
    return SplitProposal(
      subId: json['subId'] as String,
      ownerUid: json['ownerUid'] as String,
      partnerUid: json['partnerUid'] as String,
      subscriptionName: json['subscriptionName'] as String? ?? '',
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0,
      partnerSharePercent: (json['partnerSharePercent'] as num?)?.toDouble() ?? 50,
      currency: json['currency'] as String? ?? 'USD',
      accepted: json['accepted'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  final String subId;
  final String ownerUid;
  final String partnerUid;
  final String subscriptionName;
  final double totalPrice;
  final double partnerSharePercent;
  final String currency;
  final bool accepted;
  final DateTime createdAt;

  double get partnerShareAmount => totalPrice * (partnerSharePercent / 100);
  double get ownerShareAmount => totalPrice * (1 - partnerSharePercent / 100);

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

  Map<String, dynamic> toJson() {
    return {
      'subId': subId,
      'ownerUid': ownerUid,
      'partnerUid': partnerUid,
      'subscriptionName': subscriptionName,
      'totalPrice': totalPrice,
      'partnerSharePercent': partnerSharePercent,
      'currency': currency,
      'accepted': accepted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  SplitProposal copyWith({
    String? subId,
    String? ownerUid,
    String? partnerUid,
    String? subscriptionName,
    double? totalPrice,
    double? partnerSharePercent,
    String? currency,
    bool? accepted,
    DateTime? createdAt,
  }) {
    return SplitProposal(
      subId: subId ?? this.subId,
      ownerUid: ownerUid ?? this.ownerUid,
      partnerUid: partnerUid ?? this.partnerUid,
      subscriptionName: subscriptionName ?? this.subscriptionName,
      totalPrice: totalPrice ?? this.totalPrice,
      partnerSharePercent: partnerSharePercent ?? this.partnerSharePercent,
      currency: currency ?? this.currency,
      accepted: accepted ?? this.accepted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
