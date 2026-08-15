import test from 'node:test';
import assert from 'node:assert/strict';

import {
  canLeaveHousehold,
  canRemoveMember,
  canSetMemberRole,
} from './household_roles.js';

test('owner can assign admin member and guest but cannot alter owner', () => {
  assert.equal(canSetMemberRole('owner', 'member', 'admin'), true);
  assert.equal(canSetMemberRole('owner', 'admin', 'member'), true);
  assert.equal(canSetMemberRole('owner', 'guest', 'member'), true);
  assert.equal(canSetMemberRole('owner', 'owner', 'admin'), false);
  assert.equal(canSetMemberRole('owner', 'member', 'owner'), false);
});

test('admin can only switch members and guests', () => {
  assert.equal(canSetMemberRole('admin', 'member', 'guest'), true);
  assert.equal(canSetMemberRole('admin', 'guest', 'member'), true);
  assert.equal(canSetMemberRole('admin', 'member', 'admin'), false);
  assert.equal(canSetMemberRole('admin', 'admin', 'member'), false);
  assert.equal(canSetMemberRole('admin', 'owner', 'member'), false);
});

test('member and guest cannot manage roles', () => {
  assert.equal(canSetMemberRole('member', 'guest', 'member'), false);
  assert.equal(canSetMemberRole('guest', 'member', 'guest'), false);
});

test('removal follows owner/admin boundary', () => {
  assert.equal(canRemoveMember('owner', 'admin'), true);
  assert.equal(canRemoveMember('owner', 'member'), true);
  assert.equal(canRemoveMember('owner', 'guest'), true);
  assert.equal(canRemoveMember('owner', 'owner'), false);
  assert.equal(canRemoveMember('admin', 'member'), true);
  assert.equal(canRemoveMember('admin', 'guest'), true);
  assert.equal(canRemoveMember('admin', 'admin'), false);
  assert.equal(canRemoveMember('member', 'guest'), false);
});

test('non-owners can leave but owner cannot leave without transfer', () => {
  assert.equal(canLeaveHousehold('owner'), false);
  assert.equal(canLeaveHousehold('admin'), true);
  assert.equal(canLeaveHousehold('member'), true);
  assert.equal(canLeaveHousehold('guest'), true);
});
