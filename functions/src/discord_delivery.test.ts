import assert from 'node:assert/strict';
import test from 'node:test';

import {
  buildDiscordWebhookBody,
  discordDeliveryId,
  normalizeDiscordWebhookUrl,
} from './discord_delivery.js';

test('accepts canonical Discord webhook URLs and strips query/hash', () => {
  assert.equal(
    normalizeDiscordWebhookUrl(' https://discord.com/api/webhooks/123456/token-value?wait=false#x '),
    'https://discord.com/api/webhooks/123456/token-value',
  );
});

test('rejects non-Discord or malformed webhook URLs', () => {
  for (const value of [
    'http://discord.com/api/webhooks/1/token',
    'https://example.com/api/webhooks/1/token',
    'https://discord.com/channels/1/2',
    'https://user:pass@discord.com/api/webhooks/1/token',
  ]) {
    assert.throws(() => normalizeDiscordWebhookUrl(value));
  }
});

test('Discord delivery ID is deterministic and recipient-specific', () => {
  const first = discordDeliveryId('h1', 'i1', 'r1', '2026-08-20', 'u1');
  const second = discordDeliveryId('h1', 'i1', 'r1', '2026-08-20', 'u1');
  const changedItem = discordDeliveryId('h1', 'i2', 'r1', '2026-08-20', 'u1');
  const changedRecipient = discordDeliveryId('h1', 'i1', 'r1', '2026-08-20', 'u2');
  assert.equal(first, second);
  assert.notEqual(first, changedItem);
  assert.notEqual(first, changedRecipient);
  assert.match(first, /^[a-f0-9]{64}$/);
});

test('Discord payload disables mentions and includes reminder context', () => {
  const body = buildDiscordWebhookBody({
    householdName: 'Home',
    itemName: '@everyone Milk',
    expiryDate: '2026-08-20',
    title: '@everyone Milk expires soon',
    body: 'Use @everyone Milk before it expires.',
    quantity: 2,
    location: 'Fridge',
  });

  assert.equal(body.username, 'Fresh Flag');
  assert.deepEqual(body.allowed_mentions, {parse: []});
  const embeds = body.embeds as Array<Record<string, unknown>>;
  assert.equal(embeds.length, 1);
  assert.equal(embeds[0].title, '@everyone Milk expires soon');
  assert.equal(embeds[0].description, 'Use @everyone Milk before it expires.');
});

test('Discord payload accepts reminders without a location', () => {
  const body = buildDiscordWebhookBody({
    householdName: 'Home',
    itemName: 'Bread',
    expiryDate: '2026-08-20',
    title: 'Bread expires soon',
    body: 'Use Bread before it expires.',
    quantity: 1,
  });

  const embeds = body.embeds as Array<Record<string, unknown>>;
  const fields = embeds[0].fields as Array<Record<string, unknown>>;
  assert.equal(fields.some((field) => field.name === 'Location'), false);
});