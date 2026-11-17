/// Household model for Firestore
class Household {
  Household({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.members,
    required this.inviteCode,
    this.inviteExpiry,
    required this.createdAt,
    this.memberNames = const {},
  });

  factory Household.fromJson(Map<String, dynamic> json) {
    return Household(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      members: (json['members'] as List<dynamic>?)?.cast<String>() ?? [],
      inviteCode: json['inviteCode'] as String? ?? '',
      inviteExpiry: json['inviteExpiry'] != null
          ? DateTime.parse(json['inviteExpiry'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      memberNames: (json['memberNames'] as Map?)?.map(
            (k, v) => MapEntry(k as String, v as String),
          ) ??
          const {},
    );
  }

  final String id;
  final String name;
  final String createdBy;
  final List<String> members;
  final String inviteCode;
  final DateTime? inviteExpiry;
  final DateTime createdAt;

  /// Display name each member gave when creating/joining (since 1.0.6;
  /// members of older households may be missing).
  final Map<String, String> memberNames;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdBy': createdBy,
      'members': members,
      'inviteCode': inviteCode,
      'inviteExpiry': inviteExpiry?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'memberNames': memberNames,
    };
  }

  Household copyWith({
    String? id,
    String? name,
    String? createdBy,
    List<String>? members,
    String? inviteCode,
    DateTime? inviteExpiry,
    DateTime? createdAt,
    Map<String, String>? memberNames,
  }) {
    return Household(
      id: id ?? this.id,
      name: name ?? this.name,
      createdBy: createdBy ?? this.createdBy,
      members: members ?? this.members,
      inviteCode: inviteCode ?? this.inviteCode,
      inviteExpiry: inviteExpiry ?? this.inviteExpiry,
      createdAt: createdAt ?? this.createdAt,
      memberNames: memberNames ?? this.memberNames,
    );
  }
}
