import {initializeApp} from 'firebase-admin/app';
import {
  DocumentReference,
  FieldValue,
  getFirestore,
} from 'firebase-admin/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {logger} from 'firebase-functions';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {DateTime} from 'luxon';

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
      const memberUids = Array.isArray(household.memberUids)
        ? household.memberUids.filter((value): value is string => typeof value === 'string')
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

  // No explicit opt-in means no push. The client mirrors actual OS
  // notification authorization into this field after authentication.
  if (userDoc.data()?.notificationsEnabled !== true) return;

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
