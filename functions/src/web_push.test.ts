import assert from 'node:assert/strict';
import test from 'node:test';

import {
  normalizeWebPushSubscription,
  webPushDeliveryId,
  webPushSubscriptionId,
} from './web_push.js';

test('normalizes a valid Apple Web Push subscription', () => {
  const normalized = normalizeWebPushSubscription({
    endpoint: 'https://web.push.apple.com/QTest',
    expirationTime: null,
    keys: {
      p256dh: 'Abc_123-xyz',
      auth: 'Def_456-uvw',
    },
  });

  assert.equal(normalized.endpoint, 'https://web.push.apple.com/QTest');
  assert.equal(normalized.expirationTime, null);
  assert.deepEqual(normalized.keys, {
    p256dh: 'Abc_123-xyz',
    auth: 'Def_456-uvw',
  });
});

test('rejects unsupported Web Push endpoints', () => {
  assert.throws(
    () => normalizeWebPushSubscription({
      endpoint: 'https://example.com/push',
      expirationTime: null,
      keys: {p256dh: 'abc_DEF-123', auth: 'def_GHI-456'},
    }),
    /Unsupported Web Push service/,
  );
});

test('subscription ID is stable and endpoint-specific', () => {
  const a = webPushSubscriptionId('https://web.push.apple.com/a');
  const b = webPushSubscriptionId('https://web.push.apple.com/b');
  assert.equal(a, webPushSubscriptionId('https://web.push.apple.com/a'));
  assert.notEqual(a, b);
  assert.equal(a.length, 64);
});

test('web push delivery ID is channel-specific and deterministic', () => {
  const id = webPushDeliveryId(
    'house-1',
    'item-2',
    'rule-3',
    '2026-12-01',
    'user-4',
  );
  assert.equal(
    id,
    webPushDeliveryId(
      'house-1',
      'item-2',
      'rule-3',
      '2026-12-01',
      'user-4',
    ),
  );
  assert.equal(id.length, 64);
});
