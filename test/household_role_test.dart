import 'package:flutter_test/flutter_test.dart';
import 'package:freshflag/models/household.dart';
import 'package:freshflag/models/notification_rule.dart';

void main() {
  test('household roles expose the intended capabilities', () {
    expect(HouseholdRole.owner.canManageHousehold, isTrue);
    expect(HouseholdRole.admin.canManageHousehold, isTrue);
    expect(HouseholdRole.member.canManageHousehold, isFalse);
    expect(HouseholdRole.guest.canManageHousehold, isFalse);

    expect(HouseholdRole.owner.canWriteInventory, isTrue);
    expect(HouseholdRole.admin.canWriteInventory, isTrue);
    expect(HouseholdRole.member.canWriteInventory, isTrue);
    expect(HouseholdRole.guest.canWriteInventory, isFalse);
  });

  test('household member preserves safe display identity and admin role', () {
    final member = HouseholdMember(
      uid: 'user-1',
      role: HouseholdRole.admin,
      joinedAt: DateTime.utc(2026, 8, 15),
      displayName: 'Alex',
    );

    final restored = HouseholdMember.fromMap(member.uid, member.toMap());
    expect(restored.role, HouseholdRole.admin);
    expect(restored.displayName, 'Alex');
    expect(restored.effectiveDisplayName, 'Alex');
  });

  test('client reminder rendering singularizes one day', () {
    expect(
      NotificationRule.renderTemplate(
        '{item} expires in {days} days',
        item: 'Beans',
        days: 1,
        expiryDate: '2026-08-16',
        quantity: 1,
        location: '',
      ),
      'Beans expires in 1 day',
    );
  });
}
