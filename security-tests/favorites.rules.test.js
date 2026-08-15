import fs from 'node:fs';
import test, {after, before, beforeEach} from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const projectId = 'demo-freshflag-favorites';
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

function favorite(id = 'barcode-123') {
  return {
    id,
    name: 'Milk',
    quantity: 1,
    category: 'Dairy',
    barcode: '123',
    location: 'Fridge',
    sourceItemId: 'item-1',
    createdAt: '2026-08-15T12:00:00.000Z',
    updatedAt: '2026-08-15T12:00:00.000Z',
  };
}

test('users can create read update and delete only their own favorites', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  const aliceFavorite = doc(alice, 'users', 'alice', 'favorites', 'barcode-123');

  await assertSucceeds(setDoc(aliceFavorite, favorite()));
  await assertSucceeds(getDoc(aliceFavorite));
  await assertSucceeds(updateDoc(aliceFavorite, {
    quantity: 2,
    updatedAt: '2026-08-15T13:00:00.000Z',
  }));

  await assertFails(getDoc(doc(bob, 'users', 'alice', 'favorites', 'barcode-123')));
  await assertFails(setDoc(
    doc(bob, 'users', 'alice', 'favorites', 'bob-write'),
    favorite('bob-write'),
  ));

  await assertSucceeds(deleteDoc(aliceFavorite));
});
