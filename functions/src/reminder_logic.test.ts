import assert from 'node:assert/strict';
import test from 'node:test';
import {DateTime} from 'luxon';

import {deliveryId, dueWindow, renderTemplate} from './reminder_logic.js';

test('dueWindow evaluates household-local send time', () => {
  const now = DateTime.fromISO('2026-08-14T13:02:00Z', {zone: 'utc'});
  const result = dueWindow(now, 'America/Toronto', {
    daysBefore: 3,
    titleTemplate: 'x',
    bodyTemplate: 'y',
    sendTime: '09:00',
    enabled: true,
  });

  assert.equal(result.due, true);
  assert.equal(result.localSendDate, '2026-08-14');
  assert.equal(result.expiryDate, '2026-08-17');
});

test('dueWindow handles the five-minute window across local midnight', () => {
  const now = DateTime.fromISO('2026-08-15T04:01:00Z', {zone: 'utc'});
  const result = dueWindow(now, 'America/Toronto', {
    daysBefore: 1,
    titleTemplate: 'x',
    bodyTemplate: 'y',
    sendTime: '23:58',
    enabled: true,
  });

  assert.equal(result.due, true);
  assert.equal(result.localSendDate, '2026-08-14');
  assert.equal(result.expiryDate, '2026-08-15');
});

test('renderTemplate replaces all supported variables', () => {
  assert.equal(
    renderTemplate(
      '{item} x{quantity} expires in {days} days on {expiry_date} at {location}',
      {
        name: 'Milk',
        quantity: 2,
        expiryDate: '2026-08-20',
        location: 'Fridge',
      },
      3,
    ),
    'Milk x2 expires in 3 days on 2026-08-20 at Fridge',
  );
});

test('deliveryId is deterministic per recipient', () => {
  assert.equal(
    deliveryId('house', 'item', 'rule', '2026-08-20', 'user'),
    'house__item__rule__2026-08-20__user',
  );
});
