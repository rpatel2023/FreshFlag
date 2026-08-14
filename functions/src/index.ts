import {initializeApp} from 'firebase-admin/app';
import {
  DocumentReference,
  FieldValue,
  getFirestore,
} from 'firebase-admin/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {logger} from 'firebase-functions';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {DateTime} from 'luxon';

import {
  DiscordWebhookConfig,
  discordDeliveryId,
  normalizeDiscordWebhookUrl,
  sendDiscordWebhook,
} from './discord_delivery.js';
import {
  ReminderItemData,
  ReminderRuleData,
  deliveryId,
  dueWindow,
  renderTemplate,
} from './reminder_logic.js';

initializeApp();

const db = getFirestore();
const messaging = getMessaging();
const SEND_WINDOW_MINUTES = 5;
const DELIVERY_CLAIM_TTL_MINUTES = 15;
const DEVICE_STALE_DAYS = 45;

interface DeviceRegistration {
  ref: DocumentReference;
  token: string;
}

export const getDiscordIntegrationStatus = onCall(
  {region: 'us-central1'},
  async (request) => {
    const householdId = requiredString(request.data?.householdId, 'householdId');
    const uid = requireAuthenticatedUid(request.auth?.uid);
    await requireHouseholdMember(householdId, uid);

    const integration = await discordIntegrationRef(householdId).get();
    const data = integration.data();
    return {
      configured: typeof data?.webhookUrl === 'string' && data.webhookUrl.length > 0,
      enabled: data?.enabled === true,
    };
  },
);

export const setDiscordIntegration = onCall(
  {region: 'us-central1'},
  async (request) => {
    const householdId = requiredString(request.data?.householdId, 'householdId');
    const uid = requireAuthenticatedUid(request.auth?.uid);
    await requireHouseholdOwner(householdId, uid);

    const enabled = request.data?.enabled === true;
    const webhookRaw = typeof request.data?.webhookUrl === 'string'
      ? request.data.webhookUrl.trim()
      : '';
    const ref = discordIntegrationRef(householdId);
    const existing = await ref.get();
    const existingUrl = existing.data()?.webhookUrl;

    let webhookUrl: string | undefined;
    if (webhookRaw !== '') {
      try {
        webhookUrl = normalizeDiscordWebhookUrl(webhookRaw);
      } catch (error) {
        throw new HttpsError('invalid-argument', String(error));
      }
    } else if (typeof existingUrl === 'string' && existingUrl.length > 0) {
      webhookUrl = existingUrl;
    }

    if (enabled && webhookUrl == null) {
      throw new HttpsError('failed-precondition', 'A Discord webhook URL is required before enabling Discord reminders.');
    }

    await ref.set({
      type: 'discord',
      enabled,
      ...(webhookUrl == null ? {} : {webhookUrl}),
      updatedByUid: uid,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    return {configured: webhookUrl != null, enabled};
  },
);

export const testDiscordIntegration = onCall(
  {region: 'us-central1', timeoutSeconds: 30},
  async (request) => {
    const householdId = requiredString(request.data?.householdId, 'householdId');
    const uid = requireAuthenticatedUid(request.auth?.uid);
    await requireHouseholdOwner(householdId, uid);

    const [householdDoc, integrationDoc] = await Promise.all([
      db.collection('households').doc(householdId).get(),
      discordIntegrationRef(householdId).get(),
    ]);
    const webhookUrl = integrationDoc.data()?.webhookUrl;
    if (typeof webhookUrl !== 'string' || webhookUrl.length === 0) {
      throw new HttpsError('failed-precondition', 'Configure a Discord webhook first.');
    }

    try {
      await sendDiscordWebhook(webhookUrl, {
        householdName: String(householdDoc.data()?.name ?? 'FreshFlag household'),
        itemName: 'FreshFlag test reminder',
        expiryDate: DateTime.utc().toISODate() ?? 'today',
        title: 'FreshFlag Discord reminders are connected',
        body: 'This test confirms your household can receive expiry reminders in Discord.',
        quantity: 1,
        location: null,
      });
    } catch (error) {
      logger.error('Discord test delivery failed', {householdId, error});
      throw new HttpsError('unavailable', 'Discord rejected the test message. Check the webhook and try again.');
    }

    return {sent: true};
  },
);

export const processExpiryReminders = onSchedule(
  {
    schedule: '*/5 * * * *',
    timeZone: 'UTC',
    region: 'us-central1',
    timeoutSeconds: 540,
    memory: '512MiB',
    maxInstances: 1,
  },
  async () => {
    const nowUtc = DateTime.utc();
    const households = await db.collection('households').get();

    for (const householdDoc of households.docs) {
      const household = householdDoc.data();
      const timezone = household.timezone as string | undefined;
      const householdName = String(household.name ?? 'FreshFlag household');
      const memberUids = Array.isArray(household.memberUids)
        ? household.memberUids.filter((value): value is string => typeof value === 'string')
        : [];

      if (timezone == null || memberUids.length === 0) continue;

      const [rules, discordConfig] = await Promise.all([
        householdDoc.ref.collection('notificationRules')
          .where('enabled', '==', true)
          .get(),
        loadDiscordIntegration(householdDoc.id),
      ]);

      for (const ruleDoc of rules.docs) {
        const rule = ruleDoc.data() as ReminderRuleData;
        let window;
        try {
          window = dueWindow(nowUtc, timezone, rule, SEND_WINDOW_MINUTES);
        } catch (error) {
          logger.error('Skipping invalid reminder rule', {
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
            location: typeof rawItem.location === 'string' ? rawItem.location : null,
          };

          if (discordConfig?.enabled === true) {
            await deliverToDiscord({
              householdId: householdDoc.id,
              householdName,
              itemId: itemDoc.id,
              ruleId: ruleDoc.id,
              rule,
              item,
              webhookUrl: discordConfig.webhookUrl,
              nowUtc,
            });
          }

          for (const recipientUid of memberUids) {
            await deliverToRecipient({
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

export const pruneStaleDeviceRegistrations = onSchedule(
  {
    schedule: 'every day 03:15',
    timeZone: 'UTC',
    region: 'us-central1',
    timeoutSeconds: 300,
  },
  async () => {
    const cutoff = DateTime.utc().minus({days: DEVICE_STALE_DAYS}).toISO();
    if (cutoff == null) return;

    const stale = await db.collectionGroup('devices')
      .where('lastSeenAt', '<', cutoff)
      .get();

    const chunks = chunk(stale.docs, 400);
    for (const docs of chunks) {
      const batch = db.batch();
      for (const doc of docs) batch.delete(doc.ref);
      await batch.commit();
    }

    logger.info('Pruned stale device registrations', {count: stale.size});
  },
);

async function deliverToDiscord(args: {
  householdId: string;
  householdName: string;
  itemId: string;
  ruleId: string;
  rule: ReminderRuleData;
  item: ReminderItemData;
  webhookUrl: string;
  nowUtc: DateTime;
}): Promise<void> {
  const id = discordDeliveryId(
    args.householdId,
    args.itemId,
    args.ruleId,
    args.item.expiryDate,
  );
  const deliveryRef = db.collection('notificationDeliveries').doc(id);
  const claimed = await claimDelivery(deliveryRef, {
    channel: 'discord',
    householdId: args.householdId,
    itemId: args.itemId,
    ruleId: args.ruleId,
    expiryDate: args.item.expiryDate,
  }, args.nowUtc);
  if (!claimed) return;

  const title = renderTemplate(args.rule.titleTemplate, args.item, args.rule.daysBefore);
  const body = renderTemplate(args.rule.bodyTemplate, args.item, args.rule.daysBefore);

  try {
    await sendDiscordWebhook(args.webhookUrl, {
      householdName: args.householdName,
      itemName: args.item.name,
      expiryDate: args.item.expiryDate,
      title,
      body,
      quantity: args.item.quantity,
      location: args.item.location,
    });

    await deliveryRef.set({
      status: 'sent',
      sentAt: DateTime.utc().toISO(),
      successCount: 1,
      failureCount: 0,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  } catch (error) {
    await deliveryRef.set({
      status: 'failed',
      failedAt: DateTime.utc().toISO(),
      error: String(error),
      successCount: 0,
      failureCount: 1,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    logger.error('Discord reminder delivery failed', {deliveryId: id, error});
  }
}

async function deliverToRecipient(args: {
  householdId: string;
  itemId: string;
  ruleId: string;
  rule: ReminderRuleData;
  item: ReminderItemData;
  recipientUid: string;
  nowUtc: DateTime;
}): Promise<void> {
  const userRef = db.collection('users').doc(args.recipientUid);
  const userDoc = await userRef.get();
  if (userDoc.data()?.notificationsEnabled === false) return;

  const devices = await activeDeviceRegistrations(userRef, args.nowUtc);
  if (devices.length === 0) return;

  const id = deliveryId(
    args.householdId,
    args.itemId,
    args.ruleId,
    args.item.expiryDate,
    args.recipientUid,
  );
  const deliveryRef = db.collection('notificationDeliveries').doc(id);
  const claimed = await claimDelivery(deliveryRef, {
    channel: 'fcm',
    householdId: args.householdId,
    itemId: args.itemId,
    ruleId: args.ruleId,
    expiryDate: args.item.expiryDate,
    recipientUid: args.recipientUid,
  }, args.nowUtc);
  if (!claimed) return;

  const title = renderTemplate(args.rule.titleTemplate, args.item, args.rule.daysBefore);
  const body = renderTemplate(args.rule.bodyTemplate, args.item, args.rule.daysBefore);
  const tokens = devices.map((device) => device.token);

  try {
    const response = await messaging.sendEachForMulticast({
      tokens,
      notification: {title, body},
      data: {
        type: 'expiry',
        householdId: args.householdId,
        itemId: args.itemId,
        ruleId: args.ruleId,
        expiryDate: args.item.expiryDate,
      },
    });

    const invalidDeletes: Promise<unknown>[] = [];
    response.responses.forEach((result, index) => {
      if (result.success) return;
      const code = result.error?.code;
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token'
      ) {
        invalidDeletes.push(devices[index].ref.delete());
      }
    });
    await Promise.all(invalidDeletes);

    await deliveryRef.set({
      status: response.successCount > 0 ? 'sent' : 'failed',
      sentAt: DateTime.utc().toISO(),
      successCount: response.successCount,
      failureCount: response.failureCount,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  } catch (error) {
    await deliveryRef.set({
      status: 'failed',
      failedAt: DateTime.utc().toISO(),
      error: String(error),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    logger.error('Reminder delivery failed', {deliveryId: id, error});
  }
}

async function activeDeviceRegistrations(
  userRef: DocumentReference,
  nowUtc: DateTime,
): Promise<DeviceRegistration[]> {
  const snapshot = await userRef.collection('devices').get();
  const cutoff = nowUtc.minus({days: DEVICE_STALE_DAYS});

  return snapshot.docs.flatMap((doc) => {
    const data = doc.data();
    const token = data.fcmToken;
    const lastSeenRaw = data.lastSeenAt;
    if (typeof token !== 'string' || token.length === 0) return [];
    if (typeof lastSeenRaw !== 'string') return [];
    const lastSeen = DateTime.fromISO(lastSeenRaw, {zone: 'utc'});
    if (!lastSeen.isValid || lastSeen < cutoff) return [];
    return [{ref: doc.ref, token}];
  });
}

async function loadDiscordIntegration(householdId: string): Promise<DiscordWebhookConfig | null> {
  const snapshot = await discordIntegrationRef(householdId).get();
  const data = snapshot.data();
  if (data?.enabled !== true || typeof data.webhookUrl !== 'string') return null;

  try {
    return {
      enabled: true,
      webhookUrl: normalizeDiscordWebhookUrl(data.webhookUrl),
    };
  } catch (error) {
    logger.error('Ignoring invalid stored Discord integration', {householdId, error});
    return null;
  }
}

function discordIntegrationRef(householdId: string): DocumentReference {
  return db.collection('householdIntegrations').doc(householdId);
}

async function requireHouseholdMember(householdId: string, uid: string): Promise<void> {
  const member = await db.collection('households').doc(householdId).collection('members').doc(uid).get();
  if (!member.exists) {
    throw new HttpsError('permission-denied', 'You are not a member of this household.');
  }
}

async function requireHouseholdOwner(householdId: string, uid: string): Promise<void> {
  const member = await db.collection('households').doc(householdId).collection('members').doc(uid).get();
  if (!member.exists || member.data()?.role !== 'owner') {
    throw new HttpsError('permission-denied', 'Only the household owner can manage Discord reminders.');
  }
}

function requireAuthenticatedUid(uid: string | undefined): string {
  if (uid == null || uid.length === 0) {
    throw new HttpsError('unauthenticated', 'Sign in to manage Discord reminders.');
  }
  return uid;
}

function requiredString(value: unknown, field: string): string {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new HttpsError('invalid-argument', `${field} is required.`);
  }
  return value.trim();
}

async function claimDelivery(
  ref: DocumentReference,
  identity: Record<string, string>,
  nowUtc: DateTime,
): Promise<boolean> {
  return db.runTransaction(async (transaction) => {
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
      attempts: Number(existing?.attempts ?? 0) + 1,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return true;
  });
}

function chunk<T>(values: T[], size: number): T[][] {
  const result: T[][] = [];
  for (let index = 0; index < values.length; index += size) {
    result.push(values.slice(index, index + size));
  }
  return result;
}
