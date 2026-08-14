import fs from 'node:fs';
import test, {after, before, beforeEach} from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  arrayUnion,
  doc,
  getDoc,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-freshflag';
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env.cleanup();
});

async function seed(callback) {
  await env.withSecurityRulesDisabled(async (context) => {
    await callback(context.firestore());
  });
}

async function seedHousehold({
  id = 'house-1',
  ownerUid = 'owner-1',
  memberUids = ['owner-1', 'member-1'],
} = {}) {
  await seed(async (db) => {
    await setDoc(doc(db, 'households', id), {
      name: 'Test Household',
      ownerUid,
      memberUids,
      timezone: 'America/Toronto',
      createdAt: '2026-08-14T12:00:00.000Z',
      updatedAt: '2026-08-14T12:00:00.000Z',
    });
    for (const uid of memberUids) {
      await setDoc(doc(db, 'households', id, 'members', uid), {
        uid,
        role: uid === ownerUid ? 'owner' : 'member',
        joinedAt: '2026-08-14T12:00:00.000Z',
      });
    }
  });
}

async function seedInvite({
  code = 'ABCDEFGH2345',
  householdId = 'house-1',
  status = 'active',
  expiresAt = Timestamp.fromDate(new Date('2100-01-01T00:00:00.000Z')),
} = {}) {
  await seed(async (db) => {
    await setDoc(doc(db, 'invites', code), {
      householdId,
      createdByUid: 'owner-1',
      createdAt: Timestamp.fromDate(new Date('2026-08-14T12:00:00.000Z')),
      expiresAt,
      status,
    });
  });
}

test('household members can read their household but outsiders cannot', async () => {
  await seedHousehold();
  const member = env.authenticatedContext('member-1').firestore();
  const outsider = env.authenticatedContext('outsider-1').firestore();

  await assertSucceeds(getDoc(doc(member, 'households', 'house-1')));
  await assertFails(getDoc(doc(outsider, 'households', 'house-1')));
});

test('only the owner can manage notification rules', async () => {
  await seedHousehold();
  const owner = env.authenticatedContext('owner-1').firestore();
  const member = env.authenticatedContext('member-1').firestore();
  const rule = {
    daysBefore: 3,
    titleTemplate: '{item} expires soon',
    bodyTemplate: '{item} expires in {days} days.',
    sendTime: '09:00',
    enabled: true,
    createdAt: '2026-08-14T12:00:00.000Z',
    updatedAt: '2026-08-14T12:00:00.000Z',
  };

  await assertSucceeds(setDoc(doc(owner, 'households', 'house-1', 'notificationRules', 'rule-1'), rule));
  await assertFails(setDoc(doc(member, 'households', 'house-1', 'notificationRules', 'rule-2'), rule));
});

test('users can only write their own device registrations', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  const device = {
    deviceId: 'device-1',
    fcmToken: 'token',
    platform: 'ios',
    lastSeenAt: '2026-08-14T12:00:00.000Z',
  };

  await assertSucceeds(setDoc(doc(alice, 'users', 'alice', 'devices', 'device-1'), device));
  await assertFails(setDoc(doc(alice, 'users', 'bob', 'devices', 'device-1'), device));
});

test('a valid invite allows exactly the signed-in user to join without a pre-read', async () => {
  await seedHousehold({memberUids: ['owner-1']});
  await seedInvite();

  const joiningUid = 'joiner-1';
  const db = env.authenticatedContext(joiningUid).firestore();
  const householdRef = doc(db, 'households', 'house-1');
  const memberRef = doc(db, 'households', 'house-1', 'members', joiningUid);
  const userRef = doc(db, 'users', joiningUid);

  await assertFails(getDoc(householdRef));

  const batch = writeBatch(db);
  batch.update(householdRef, {
    memberUids: arrayUnion(joiningUid),
    lastJoinInviteId: 'ABCDEFGH2345',
    updatedAt: '2026-08-14T13:00:00.000Z',
  });
  batch.set(memberRef, {
    uid: joiningUid,
    role: 'member',
    joinedAt: '2026-08-14T13:00:00.000Z',
    inviteId: 'ABCDEFGH2345',
  });
  batch.set(userRef, {
    currentHouseholdId: 'house-1',
    updatedAt: '2026-08-14T13:00:00.000Z',
  }, {merge: true});

  await assertSucceeds(batch.commit());
  await assertSucceeds(getDoc(householdRef));
});

test('revoked and expired invites cannot authorize a join', async () => {
  for (const scenario of [
    {status: 'revoked', expiresAt: Timestamp.fromDate(new Date('2100-01-01T00:00:00.000Z'))},
    {status: 'active', expiresAt: Timestamp.fromDate(new Date('2020-01-01T00:00:00.000Z'))},
  ]) {
    await env.clearFirestore();
    await seedHousehold({memberUids: ['owner-1']});
    await seedInvite(scenario);

    const uid = 'joiner-1';
    const db = env.authenticatedContext(uid).firestore();
    const batch = writeBatch(db);
    batch.update(doc(db, 'households', 'house-1'), {
      memberUids: arrayUnion(uid),
      lastJoinInviteId: 'ABCDEFGH2345',
      updatedAt: '2026-08-14T13:00:00.000Z',
    });
    batch.set(doc(db, 'households', 'house-1', 'members', uid), {
      uid,
      role: 'member',
      joinedAt: '2026-08-14T13:00:00.000Z',
      inviteId: 'ABCDEFGH2345',
    });
    await assertFails(batch.commit());
  }
});

test('a member cannot escalate their role to owner', async () => {
  await seedHousehold();
  const member = env.authenticatedContext('member-1').firestore();
  await assertFails(updateDoc(doc(member, 'households', 'house-1', 'members', 'member-1'), {
    role: 'owner',
  }));
});

test('membership in one household does not authorize writes to another', async () => {
  await seedHousehold({id: 'house-a', memberUids: ['owner-1', 'member-1']});
  await seedHousehold({id: 'house-b', ownerUid: 'owner-2', memberUids: ['owner-2']});
  const member = env.authenticatedContext('member-1').firestore();

  await assertFails(setDoc(doc(member, 'households', 'house-b', 'items', 'item-1'), {
    id: 'item-1',
    householdId: 'house-b',
    name: 'Milk',
    quantity: 1,
    category: 'Dairy',
    addedDate: '2026-08-14T12:00:00.000Z',
    expiryDate: '2026-08-20',
    createdByUid: 'member-1',
    updatedByUid: 'member-1',
  }));
});

test('notification delivery ledger is inaccessible to clients', async () => {
  const user = env.authenticatedContext('user-1').firestore();
  await assertFails(setDoc(doc(user, 'notificationDeliveries', 'delivery-1'), {
    status: 'sent',
  }));
  await assertFails(getDoc(doc(user, 'notificationDeliveries', 'delivery-1')));
});

test('per-user integration secrets are inaccessible even to their owner', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'userIntegrations', 'alice'), {
      type: 'discord',
      uid: 'alice',
      enabled: true,
      webhookUrl: 'https://discord.com/api/webhooks/123/token',
    });
  });

  const alice = env.authenticatedContext('alice').firestore();
  await assertFails(getDoc(doc(alice, 'userIntegrations', 'alice')));
  await assertFails(setDoc(doc(alice, 'userIntegrations', 'alice'), {
    type: 'discord',
    uid: 'alice',
    enabled: false,
  }));
  await assertFails(getDoc(doc(alice, 'userIntegrations', 'bob')));
});
