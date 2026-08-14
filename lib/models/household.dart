class Household {
  const Household({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.memberUids,
    required this.timezone,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String ownerUid;
  final List<String> memberUids;
  final String timezone;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'name': name,
        'ownerUid': ownerUid,
        'memberUids': memberUids,
        'timezone': timezone,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Household.fromMap(String id, Map<String, dynamic> map) {
    return Household(
      id: id,
      name: map['name'] as String? ?? 'Household',
      ownerUid: map['ownerUid'] as String,
      memberUids: List<String>.from(map['memberUids'] as List? ?? const []),
      timezone: map['timezone'] as String? ?? 'UTC',
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

enum HouseholdRole { owner, member }

class HouseholdMember {
  const HouseholdMember({
    required this.uid,
    required this.role,
    required this.joinedAt,
  });

  final String uid;
  final HouseholdRole role;
  final DateTime joinedAt;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'role': role.name,
        'joinedAt': joinedAt.toIso8601String(),
      };

  factory HouseholdMember.fromMap(String uid, Map<String, dynamic> map) {
    final rawRole = map['role'] as String? ?? HouseholdRole.member.name;
    return HouseholdMember(
      uid: uid,
      role: HouseholdRole.values.firstWhere(
        (role) => role.name == rawRole,
        orElse: () => HouseholdRole.member,
      ),
      joinedAt: DateTime.parse(map['joinedAt'] as String),
    );
  }
}
