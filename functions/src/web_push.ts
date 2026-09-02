import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';

import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {logger} from 'firebase-functions';
import {defineSecret} from 'firebase-functions/params';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {DateTime} from 'luxon';

import {APP_DISPLAY_NAME} from './brand.js';
import {
  ReminderItemData,
  ReminderRuleData,
  dueWindow,
  renderTemplate,
} from './reminder_logic.js';

const require = createRequire(import.meta.url);
const webPush = require('web-push') as WebPushModule;

const VAPID_PUBLIC_KEY = defineSecret('WEB_PUSH_VAPID_PUBLIC_KEY');
const VAPID_PRIVATE_KEY = defineSecret('WEB_PUSH_VAPID_PRIVATE_KEY');
const VAPID_SUBJECT = 'https://freshflag.ca';
const SEND_WINDOW_MINUTES = 5;
const DELIVERY_CLAIM_TTL_MINUTES = 15;

interface WebPushModule {
  setVapidDetails(subject: string, publicKey: string, privateKey: string): void;
  sendNotification(
    subscription: WebPushSubscription,
    payload: string,
    options?: {TTL?: number; urgency?: 'very-low' | 'low' | 'normal' | 'high'},
  ): Promise<unknown>;
}

export interface WebPushSubscription {
  endpoint: string;
  expirationTime: number | null;
  keys: {
    p256dh: string;
    auth: string;
  };
}

interface StoredWebPushSubscription extends WebPushSubscription {
  refPath: string;
}

interface WebPushPayload {
  title: string;
  body: string;
  tag: string;
  data: {
    type: 'expiry' | 'test';
    householdId?: string;
    itemId?: string;
    ruleId?: string;
    expiryDate?: string;
  };
}

export const getWebPushPublicKey = onCall(
  {
    region: 'us-central1',
    secrets: [VAPID_PUBLIC_KEY],
  },
  async (request) => {
    requireAuthenticatedUid(request.auth?.uid);
    const publicKey = VAPID_PUBLIC_KEY.value().trim();
    if (!isBase64Url(publicKey)) {
      logger.error('WEB_PUSH_VAPID_PUBLIC_KEY is not configured correctly.');
      throw new HttpsError(
        'failed-precondition',
        'Web Push is not configured yet.',
      );
    }
    return {publicKey};
  },
);

export const setWebPushSubscription = onCall(
  {region: 'us-central1'},
  async (request) => {
    const uid = requireAuthenticatedUid(request.auth?.uid);
    let subscription: WebPushSubscription;
    try {
      subscription = normalizeWebPushSubscription(request.data?.subscription);
    } catch (error) {
      throw new HttpsError('invalid-argument', String(error));
    }

    const id = webPushSubscriptionId(subscription.endpoint);
    const ref = getFirestore()
      .collection('users')
      .doc(uid)
      .collection('webPushSubscriptions')
      .doc(id);
    const existing = await ref.get();
    const userAgent = request.rawRequest.get('user-agent')?.slice(0, 500) ?? null;

    await ref.set({
      type: 'webpush',
      enabled: true,
      endpoint: subscription.endpoint,
      expirationTime: subscription.expirationTime,
      keys: subscription.keys,
      userAgent,
      ...(existing.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    return {enabled: true};
  },
);

export const removeWebPushSubscription = onCall(
  {region: 'us-central1'},
  async (request) => {
    const uid = requireAuthenticatedUid(request.auth?.uid);
    const endpoint = typeof request.data?.endpoint === 'string'
      ? request.data.endpoint.trim()
      : '';
    let normalizedEndpoint: string;
    try {
      normalizedEndpoint = normalizePushEndpoint(endpoint);
    } catch (error) {
      throw new HttpsError('invalid-argument', String(error));
    }

    await getFirestore()
      .collection('users')
      .doc(uid)
      .collection('webPushSubscriptions')
      .doc(webPushSubscriptionId(normalizedEndpoint))
      .delete();

    return {enabled: false};
  },
);

export const testWebPushNotification = onCall(
  {
    region: 'us-central1',
    timeoutSeconds: 30,
    secrets: [VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY],
  },
  async (request) => {
    const uid = requireAuthenticatedUid(request.auth?.uid);
    const subscriptions = await activeWebPushSubscriptions(uid);
    if (subscriptions.length === 0) {
      throw new HttpsError(
        'failed-precondition',
        'Enable reminder notifications on this device first.',
      );
    }

    configureWebPush();
    const result = await sendToSubscriptions(
      subscriptions,
      {
        title: `${APP_DISPLAY_NAME} reminders are connected`,
        body: 'This test confirms this Home Screen companion can receive reminder notifications.',
        tag: `freshflag-test-${Date.now()}`,
        data: {type: 'test'},
      },
    );

    if (result.successCount === 0) {
      throw new HttpsError(
        'unavailable',
        'The push service did not accept the test notification.',
      );
    }
    return result;
  },
);

export const processWebPushExpiryReminders = onSchedule(
  {
    schedule: '*/5 * * * *',
    timeZone: 'UTC',
    region: 'us-central1',
    timeoutSeconds: 540,
    memory: '512MiB',
    maxInstances: 1,
    secrets: [VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY],
  },
  async () => {
    configureWebPush();
    const nowUtc = DateTime.utc();
    const households = await getFirestore().collection('households').get();

    for (const householdDoc of households.docs) {
      const household = householdDoc.data();
      const timezone = typeof household.timezone === 'string'
        ? household.timezone
        : null;
      const memberUids = Array.isArray(household.memberUids)
        ? household.memberUids.filter(
          (value): value is string => typeof value === 'string',
        )
        : [];
      if (timezone == null || memberUids.length === 0) continue;

      const rules = await householdDoc.ref.collection('notificationRules')
        .where('enabled', '==', true)
        .get();

      for (const ruleDoc of rules.docs) {
        const rule = ruleDoc.data() as ReminderRuleData;
        let window;
        try {
          window = dueWindow(nowUtc, timezone, rule, SEND_WINDOW_MINUTES);
        } catch (error) {
          logger.error('Skipping invalid Web Push reminder rule', {
            householdId: householdDoc.id,
            ruleId: ruleDoc.id,
            error,
          });
          continue;
        }
        if (!window.due) continue;

        const items = await householdDoc.ref.collection('items')
          .where('expiryDate', '==', window.expiryDate)
          .get();

        for (const itemDoc of items.docs) {
          const rawItem = itemDoc.data();
          if (rawItem.isConsumed === true) continue;

          const item: ReminderItemData = {
            name: String(rawItem.name ?? 'Item'),
            quantity: Number(rawItem.quantity ?? 1),
            expiryDate: String(rawItem.expiryDate ?? window.expiryDate),
            location: typeof rawItem.location === 'string'
              ? rawItem.location
              : null,
          };

          for (const recipientUid of memberUids) {
            await deliverReminderToWebPush({
              householdId: householdDoc.id,
              itemId: itemDoc.id,
              ruleId: ruleDoc.id,
              rule,
              item,
              recipientUid,
              nowUtc,
            });
          }
        }
      }
    }
  },
);

async function deliverReminderToWebPush(args: {
  householdId: string;
  itemId: string;
  ruleId: string;
  rule: ReminderRuleData;
  item: ReminderItemData;
  recipientUid: string;
  nowUtc: DateTime;
}): Promise<void> {
  const subscriptions = await activeWebPushSubscriptions(args.recipientUid);
  if (subscriptions.length === 0) return;

  const id = webPushDeliveryId(
    args.householdId,
    args.itemId,
    args.ruleId,
    args.item.expiryDate,
    args.recipientUid,
  );
  const deliveryRef = getFirestore().collection('notificationDeliveries').doc(id);
  const claimed = await claimDelivery(deliveryRef, {
    channel: 'webpush',
    householdId: args.householdId,
    itemId: args.itemId,
    ruleId: args.ruleId,
    expiryDate: args.item.expiryDate,
    recipientUid: args.recipientUid,
  }, args.nowUtc);
  if (!claimed) return;

  const title = renderTemplate(
    args.rule.titleTemplate,
    args.item,
    args.rule.daysBefore,
  );
  const body = renderTemplate(
    args.rule.bodyTemplate,
    args.item,
    args.rule.daysBefore,
  );

  try {
    const result = await sendToSubscriptions(subscriptions, {
      title,
      body,
      tag: webPushTag(
        args.householdId,
        args.itemId,
        args.ruleId,
        args.item.expiryDate,
      ),
      data: {
        type: 'expiry',
        householdId: args.householdId,
        itemId: args.itemId,
        ruleId: args.ruleId,
        expiryDate: args.item.expiryDate,
      },
    });

    await deliveryRef.set({
      status: result.successCount > 0 ? 'sent' : 'failed',
      sentAt: DateTime.utc().toISO(),
      successCount: result.successCount,
      failureCount: result.failureCount,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  } catch (error) {
    await deliveryRef.set({
      status: 'failed',
      failedAt: DateTime.utc().toISO(),
      error: String(error),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    logger.error('Web Push reminder delivery failed', {
      deliveryId: id,
      recipientUid: args.recipientUid,
      error,
    });
  }
}

async function activeWebPushSubscriptions(
  uid: string,
): Promise<StoredWebPushSubscription[]> {
  const snapshot = await getFirestore()
    .collection('users')
    .doc(uid)
    .collection('webPushSubscriptions')
    .get();

  return snapshot.docs.flatMap((doc) => {
    const data = doc.data();
    if (data.enabled !== true) return [];
    try {
      const subscription = normalizeWebPushSubscription(data);
      return [{...subscription, refPath: doc.ref.path}];
    } catch (error) {
      logger.warn('Ignoring invalid stored Web Push subscription', {
        uid,
        subscriptionId: doc.id,
        error,
      });
      return [];
    }
  });
}

async function sendToSubscriptions(
  subscriptions: StoredWebPushSubscription[],
  payload: WebPushPayload,
): Promise<{successCount: number; failureCount: number}> {
  let successCount = 0;
  let failureCount = 0;

  for (const subscription of subscriptions) {
    try {
      await webPush.sendNotification(
        {
          endpoint: subscription.endpoint,
          expirationTime: subscription.expirationTime,
          keys: subscription.keys,
        },
        JSON.stringify(payload),
        {TTL: 60 * 60 * 24, urgency: 'normal'},
      );
      successCount += 1;
    } catch (error) {
      failureCount += 1;
      const statusCode = webPushStatusCode(error);
      if (statusCode === 404 || statusCode === 410) {
        await getFirestore().doc(subscription.refPath).delete();
        logger.info('Removed expired Web Push subscription', {
          refPath: subscription.refPath,
          statusCode,
        });
      } else {
        logger.error('Web Push endpoint rejected notification', {
          refPath: subscription.refPath,
          statusCode,
          error,
        });
      }
    }
  }

  return {successCount, failureCount};
}

function configureWebPush(): void {
  const publicKey = VAPID_PUBLIC_KEY.value().trim();
  const privateKey = VAPID_PRIVATE_KEY.value().trim();
  if (!isBase64Url(publicKey) || !isBase64Url(privateKey)) {
    throw new Error('Web Push VAPID secrets are not configured correctly.');
  }
  webPush.setVapidDetails(VAPID_SUBJECT, publicKey, privateKey);
}

export function normalizeWebPushSubscription(raw: unknown): WebPushSubscription {
  if (typeof raw !== 'object' || raw == null) {
    throw new Error('Web Push subscription is required');
  }
  const candidate = raw as Record<string, unknown>;
  const endpoint = normalizePushEndpoint(candidate.endpoint);
  const keysRaw = candidate.keys;
  if (typeof keysRaw !== 'object' || keysRaw == null) {
    throw new Error('Web Push subscription keys are required');
  }
  const keys = keysRaw as Record<string, unknown>;
  const p256dh = normalizeSubscriptionKey(keys.p256dh, 'p256dh');
  const auth = normalizeSubscriptionKey(keys.auth, 'auth');
  const expirationTime = candidate.expirationTime == null
    ? null
    : Number(candidate.expirationTime);
  if (
    expirationTime != null &&
    (!Number.isFinite(expirationTime) || expirationTime < 0)
  ) {
    throw new Error('Invalid Web Push expiration time');
  }
  return {endpoint, expirationTime, keys: {p256dh, auth}};
}

export function webPushSubscriptionId(endpoint: string): string {
  return createHash('sha256').update(endpoint).digest('hex');
}

export function webPushDeliveryId(
  householdId: string,
  itemId: string,
  ruleId: string,
  expiryDate: string,
  recipientUid: string,
): string {
  const raw = [
    'webpush',
    householdId,
    itemId,
    ruleId,
    expiryDate,
    recipientUid,
  ].join('|');
  return createHash('sha256').update(raw).digest('hex');
}

function webPushTag(
  householdId: string,
  itemId: string,
  ruleId: string,
  expiryDate: string,
): string {
  const raw = [householdId, itemId, ruleId, expiryDate].join('|');
  return `freshflag-${createHash('sha256').update(raw).digest('hex').slice(0, 24)}`;
}

function normalizePushEndpoint(raw: unknown): string {
  if (typeof raw !== 'string' || raw.trim().length === 0) {
    throw new Error('Web Push endpoint is required');
  }
  if (raw.length > 2048) throw new Error('Web Push endpoint is too long');

  let parsed: URL;
  try {
    parsed = new URL(raw.trim());
  } catch {
    throw new Error('Invalid Web Push endpoint');
  }
  if (parsed.protocol !== 'https:') {
    throw new Error('Web Push endpoint must use HTTPS');
  }
  if (parsed.username !== '' || parsed.password !== '') {
    throw new Error('Web Push endpoint must not contain credentials');
  }
  if (!isAllowedPushHost(parsed.hostname.toLowerCase())) {
    throw new Error('Unsupported Web Push service');
  }
  parsed.hash = '';
  return parsed.toString();
}

function isAllowedPushHost(hostname: string): boolean {
  return hostname === 'fcm.googleapis.com' ||
    hostname === 'updates.push.services.mozilla.com' ||
    hostname === 'push.services.mozilla.com' ||
    hostname.endsWith('.push.apple.com');
}

function normalizeSubscriptionKey(raw: unknown, name: string): string {
  if (typeof raw !== 'string') {
    throw new Error(`Web Push ${name} key is required`);
  }
  const value = raw.trim();
  if (value.length === 0 || value.length > 512 || !isBase64Url(value)) {
    throw new Error(`Invalid Web Push ${name} key`);
  }
  return value;
}

function isBase64Url(value: string): boolean {
  return /^[A-Za-z0-9_-]+$/.test(value);
}

function requireAuthenticatedUid(uid: string | undefined): string {
  if (uid == null || uid.length === 0) {
    throw new HttpsError(
      'unauthenticated',
      'Sign in to manage reminder notifications.',
    );
  }
  return uid;
}

async function claimDelivery(
  ref: FirebaseFirestore.DocumentReference,
  identity: Record<string, string>,
  nowUtc: DateTime,
): Promise<boolean> {
  return getFirestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const existing = snapshot.data();
    if (existing?.status === 'sent') return false;

    if (existing?.status === 'claimed' && typeof existing.claimedAt === 'string') {
      const claimedAt = DateTime.fromISO(existing.claimedAt, {zone: 'utc'});
      if (
        claimedAt.isValid &&
        nowUtc.diff(claimedAt, 'minutes').minutes < DELIVERY_CLAIM_TTL_MINUTES
      ) {
        return false;
      }
    }

    transaction.set(ref, {
      ...identity,
      status: 'claimed',
      claimedAt: nowUtc.toISO(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return true;
  });
}

function webPushStatusCode(error: unknown): number | null {
  if (typeof error !== 'object' || error == null || !('statusCode' in error)) {
    return null;
  }
  const value = Number((error as {statusCode?: unknown}).statusCode);
  return Number.isInteger(value) ? value : null;
}
