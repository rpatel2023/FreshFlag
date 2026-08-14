/// Validated navigation intent carried by an FCM data payload.
///
/// Only expiry notifications with both household and item identifiers can
/// become navigation targets. The legacy `expiry_reminder` type remains
/// accepted while deployed Phase 6 messages age out.
class NotificationTarget {
  const NotificationTarget({
    required this.householdId,
    required this.itemId,
  });

  final String householdId;
  final String itemId;

  String get key => '$householdId:$itemId';

  static NotificationTarget? fromData(Map<String, dynamic> data) {
    final type = data['type']?.toString().trim();
    if (type != 'expiry' && type != 'expiry_reminder') return null;

    final householdId = data['householdId']?.toString().trim() ?? '';
    final itemId = data['itemId']?.toString().trim() ?? '';
    if (householdId.isEmpty || itemId.isEmpty) return null;

    return NotificationTarget(
      householdId: householdId,
      itemId: itemId,
    );
  }
}
