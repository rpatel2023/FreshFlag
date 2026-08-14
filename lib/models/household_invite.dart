enum HouseholdInviteStatus { active, revoked }

class HouseholdInvite {
  const HouseholdInvite({
    required this.code,
    required this.householdId,
    required this.createdByUid,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
  });

  final String code;
  final String householdId;
  final String createdByUid;
  final DateTime createdAt;
  final DateTime expiresAt;
  final HouseholdInviteStatus status;

  bool get isActive =>
      status == HouseholdInviteStatus.active &&
      expiresAt.isAfter(DateTime.now().toUtc());

  static String normalizeCode(String value) =>
      value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}
