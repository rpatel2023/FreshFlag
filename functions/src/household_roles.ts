export type HouseholdRole = 'owner' | 'admin' | 'member' | 'guest';

export const assignableRoles: HouseholdRole[] = ['admin', 'member', 'guest'];

export function isHouseholdRole(value: unknown): value is HouseholdRole {
  return value === 'owner' || value === 'admin' || value === 'member' || value === 'guest';
}

export function canSetMemberRole(
  callerRole: HouseholdRole,
  targetRole: HouseholdRole,
  nextRole: HouseholdRole,
): boolean {
  if (targetRole === 'owner' || nextRole === 'owner') return false;

  if (callerRole === 'owner') {
    return assignableRoles.includes(nextRole);
  }

  if (callerRole === 'admin') {
    return (targetRole === 'member' || targetRole === 'guest') &&
      (nextRole === 'member' || nextRole === 'guest');
  }

  return false;
}

export function canRemoveMember(
  callerRole: HouseholdRole,
  targetRole: HouseholdRole,
): boolean {
  if (targetRole === 'owner') return false;
  if (callerRole === 'owner') return true;
  if (callerRole === 'admin') {
    return targetRole === 'member' || targetRole === 'guest';
  }
  return false;
}
