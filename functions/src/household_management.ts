import {getAuth} from 'firebase-admin/auth';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';

import {
  HouseholdRole,
  canLeaveHousehold,
  canRemoveMember,
  canSetMemberRole,
  isHouseholdRole,
} from './household_roles.js';

function requireUid(uid: string | undefined): string {
  if (uid == null || uid.length === 0) {
    throw new HttpsError('unauthenticated', 'Sign in to manage household members.');
  }
  return uid;
}

function requireHouseholdId(value: unknown): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'A household ID is required.');
  }
  return value.trim();
}

async function readRole(householdId: string, uid: string): Promise<HouseholdRole> {
  const snapshot = await getFirestore()
      .collection('households')
      .doc(householdId)
      .collection('members')
      .doc(uid)
      .get();
  const role = snapshot.data()?.role;
  if (!isHouseholdRole(role)) {
    throw new HttpsError('permission-denied', 'You are not a member of this household.');
  }
  return role;
}

export const listHouseholdMembers = onCall(
  {region: 'us-central1'},
  async (request) => {
    const callerUid = requireUid(request.auth?.uid);
    const householdId = requireHouseholdId(request.data?.householdId);
    await readRole(householdId, callerUid);

    const members = await getFirestore()
        .collection('households')
        .doc(householdId)
        .collection('members')
        .get();

    const identifiers = members.docs.map((doc) => ({uid: doc.id}));
    const usersByUid = new Map<string, string>();
    if (identifiers.length > 0) {
      const result = await getAuth().getUsers(identifiers);
      for (const user of result.users) {
        const displayName = user.displayName?.trim();
        if (displayName != null && displayName.length > 0) {
          usersByUid.set(user.uid, displayName);
        }
      }
    }

    return {
      members: members.docs.map((doc) => {
        const data = doc.data();
        const storedName = typeof data.displayName === 'string'
          ? data.displayName.trim()
          : '';
        return {
          uid: doc.id,
          role: isHouseholdRole(data.role) ? data.role : 'member',
          joinedAt: typeof data.joinedAt === 'string' ? data.joinedAt : new Date(0).toISOString(),
          displayName: usersByUid.get(doc.id) ?? storedName,
        };
      }),
    };
  },
);

export const setHouseholdMemberRole = onCall(
  {region: 'us-central1'},
  async (request) => {
    const callerUid = requireUid(request.auth?.uid);
    const householdId = requireHouseholdId(request.data?.householdId);
    const targetUid = typeof request.data?.uid === 'string' ? request.data.uid.trim() : '';
    const nextRole = request.data?.role;
    if (targetUid.length === 0 || !isHouseholdRole(nextRole) || nextRole === 'owner') {
      throw new HttpsError('invalid-argument', 'Choose a valid member and role.');
    }

    const db = getFirestore();
    const householdRef = db.collection('households').doc(householdId);
    const callerRef = householdRef.collection('members').doc(callerUid);
    const targetRef = householdRef.collection('members').doc(targetUid);

    await db.runTransaction(async (transaction) => {
      const [householdSnapshot, callerSnapshot, targetSnapshot] = await Promise.all([
        transaction.get(householdRef),
        transaction.get(callerRef),
        transaction.get(targetRef),
      ]);
      const household = householdSnapshot.data();
      const callerRole = callerSnapshot.data()?.role;
      const targetRole = targetSnapshot.data()?.role;

      if (!householdSnapshot.exists || !isHouseholdRole(callerRole)) {
        throw new HttpsError('permission-denied', 'You cannot manage this household.');
      }
      if (!targetSnapshot.exists || !isHouseholdRole(targetRole)) {
        throw new HttpsError('not-found', 'Household member not found.');
      }
      if (household?.ownerUid === targetUid || !canSetMemberRole(callerRole, targetRole, nextRole)) {
        throw new HttpsError('permission-denied', 'You cannot assign that role.');
      }

      transaction.update(targetRef, {
        role: nextRole,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    return {uid: targetUid, role: nextRole};
  },
);

export const removeHouseholdMember = onCall(
  {region: 'us-central1'},
  async (request) => {
    const callerUid = requireUid(request.auth?.uid);
    const householdId = requireHouseholdId(request.data?.householdId);
    const targetUid = typeof request.data?.uid === 'string' ? request.data.uid.trim() : '';
    if (targetUid.length === 0) {
      throw new HttpsError('invalid-argument', 'Choose a household member to remove.');
    }

    const db = getFirestore();
    const householdRef = db.collection('households').doc(householdId);
    const callerRef = householdRef.collection('members').doc(callerUid);
    const targetRef = householdRef.collection('members').doc(targetUid);
    const userRef = db.collection('users').doc(targetUid);

    await db.runTransaction(async (transaction) => {
      const [householdSnapshot, callerSnapshot, targetSnapshot, userSnapshot] = await Promise.all([
        transaction.get(householdRef),
        transaction.get(callerRef),
        transaction.get(targetRef),
        transaction.get(userRef),
      ]);
      const household = householdSnapshot.data();
      const callerRole = callerSnapshot.data()?.role;
      const targetRole = targetSnapshot.data()?.role;

      if (!householdSnapshot.exists || !isHouseholdRole(callerRole)) {
        throw new HttpsError('permission-denied', 'You cannot manage this household.');
      }
      if (!targetSnapshot.exists || !isHouseholdRole(targetRole)) {
        throw new HttpsError('not-found', 'Household member not found.');
      }
      if (household?.ownerUid === targetUid || !canRemoveMember(callerRole, targetRole)) {
        throw new HttpsError('permission-denied', 'You cannot remove that member.');
      }

      transaction.update(householdRef, {
        memberUids: FieldValue.arrayRemove(targetUid),
        updatedAt: new Date().toISOString(),
      });
      transaction.delete(targetRef);

      if (userSnapshot.data()?.currentHouseholdId === householdId) {
        transaction.set(userRef, {
          currentHouseholdId: FieldValue.delete(),
          updatedAt: new Date().toISOString(),
        }, {merge: true});
      }
    });

    return {removed: true, uid: targetUid};
  },
);

export const leaveHousehold = onCall(
  {region: 'us-central1'},
  async (request) => {
    const callerUid = requireUid(request.auth?.uid);
    const householdId = requireHouseholdId(request.data?.householdId);
    const db = getFirestore();
    const householdRef = db.collection('households').doc(householdId);
    const memberRef = householdRef.collection('members').doc(callerUid);
    const userRef = db.collection('users').doc(callerUid);

    await db.runTransaction(async (transaction) => {
      const [householdSnapshot, memberSnapshot, userSnapshot] = await Promise.all([
        transaction.get(householdRef),
        transaction.get(memberRef),
        transaction.get(userRef),
      ]);
      const household = householdSnapshot.data();
      const role = memberSnapshot.data()?.role;

      if (!householdSnapshot.exists || !memberSnapshot.exists || !isHouseholdRole(role)) {
        throw new HttpsError('not-found', 'Household membership not found.');
      }
      if (household?.ownerUid === callerUid || !canLeaveHousehold(role)) {
        throw new HttpsError(
          'failed-precondition',
          'The household owner cannot leave until ownership is transferred.',
        );
      }

      transaction.update(householdRef, {
        memberUids: FieldValue.arrayRemove(callerUid),
        updatedAt: new Date().toISOString(),
      });
      transaction.delete(memberRef);
      if (userSnapshot.data()?.currentHouseholdId === householdId) {
        transaction.set(userRef, {
          currentHouseholdId: FieldValue.delete(),
          updatedAt: new Date().toISOString(),
        }, {merge: true});
      }
    });

    return {left: true, householdId};
  },
);
