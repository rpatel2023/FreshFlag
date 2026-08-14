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

test('Discord delivery ID is deterministic and channel-specific', () => {
  const first = discordDeliveryId('h1', 'i1', 'r1', '2026-08-20');
  const second = discordDeliveryId('h1', 'i1', 'r1', '2026-08-20');
  const changed = discordDeliveryId('h1', 'i2', 'r1', '2026-08-20');
  assert.equal(first, second);
  assert.notEqual(first, changed);
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

  assert.deepEqual(body.allowed_mentions, {parse: []});
  const embeds = body.embeds as Array<Record<string, unknown>>;
  assert.equal(embeds.length, 1);
  assert.equal(embeds[0].title, '@everyone Milk expires soon');
  assert.equal(embeds[0].description, 'Use @everyone Milk before it expires.');
});
