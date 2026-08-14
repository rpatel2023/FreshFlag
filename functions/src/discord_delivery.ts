import {createHash} from 'node:crypto';

export interface DiscordWebhookConfig {
  enabled: boolean;
  webhookUrl: string;
}

export interface DiscordReminderPayload {
  householdName: string;
  itemName: string;
  expiryDate: string;
  title: string;
  body: string;
  quantity: number;
  location: string | null;
}

const ALLOWED_HOSTS = new Set(['discord.com', 'discordapp.com']);
const WEBHOOK_PATH = /^\/api\/webhooks\/([0-9]+)\/([^/?#]+)$/;

export function normalizeDiscordWebhookUrl(raw: string): string {
  const value = raw.trim();
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    throw new Error('Invalid Discord webhook URL');
  }

  if (parsed.protocol !== 'https:') {
    throw new Error('Discord webhook URL must use HTTPS');
  }
  if (parsed.username !== '' || parsed.password !== '') {
    throw new Error('Discord webhook URL must not contain credentials');
  }
  if (!ALLOWED_HOSTS.has(parsed.hostname.toLowerCase())) {
    throw new Error('Webhook URL must use discord.com');
  }
  if (!WEBHOOK_PATH.test(parsed.pathname)) {
    throw new Error('Invalid Discord webhook path');
  }

  parsed.hash = '';
  parsed.search = '';
  return parsed.toString();
}

export function discordDeliveryId(
  householdId: string,
  itemId: string,
  ruleId: string,
  expiryDate: string,
): string {
  const raw = ['discord', householdId, itemId, ruleId, expiryDate].join('|');
  return createHash('sha256').update(raw).digest('hex');
}

export function buildDiscordWebhookBody(payload: DiscordReminderPayload): Record<string, unknown> {
  const fields: Array<Record<string, unknown>> = [
    {name: 'Expires', value: payload.expiryDate, inline: true},
    {name: 'Quantity', value: String(payload.quantity), inline: true},
  ];

  if (payload.location != null && payload.location.trim() !== '') {
    fields.push({name: 'Location', value: payload.location.trim(), inline: true});
  }

  return {
    username: 'FreshFlag',
    allowed_mentions: {parse: []},
    embeds: [
      {
        title: truncate(payload.title, 256),
        description: truncate(payload.body, 4096),
        fields,
        footer: {text: truncate(`${payload.householdName} • ${payload.itemName}`, 2048)},
      },
    ],
  };
}

export async function sendDiscordWebhook(
  webhookUrl: string,
  payload: DiscordReminderPayload,
): Promise<void> {
  const url = new URL(normalizeDiscordWebhookUrl(webhookUrl));
  url.searchParams.set('wait', 'true');

  const response = await fetch(url, {
    method: 'POST',
    headers: {'content-type': 'application/json'},
    body: JSON.stringify(buildDiscordWebhookBody(payload)),
  });

  if (!response.ok) {
    const retryAfter = response.headers.get('retry-after');
    const detail = (await response.text()).slice(0, 500);
    throw new Error(
      `Discord webhook failed (${response.status})${retryAfter == null ? '' : ` retry-after=${retryAfter}`}: ${detail}`,
    );
  }
}

function truncate(value: string, maxLength: number): string {
  if (value.length <= maxLength) return value;
  return `${value.slice(0, Math.max(0, maxLength - 1))}…`;
}
