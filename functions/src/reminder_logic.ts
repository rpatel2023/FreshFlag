import {DateTime} from 'luxon';

export interface ReminderRuleData {
  daysBefore: number;
  titleTemplate: string;
  bodyTemplate: string;
  sendTime: string;
  enabled: boolean;
}

export interface ReminderItemData {
  name: string;
  quantity: number;
  expiryDate: string;
  location?: string | null;
}

export interface DueRuleWindow {
  due: boolean;
  localSendDate: string;
  expiryDate: string;
}

export function dueWindow(
  nowUtc: DateTime,
  timezone: string,
  rule: ReminderRuleData,
  windowMinutes = 5,
): DueRuleWindow {
  const localNow = nowUtc.setZone(timezone);
  if (!localNow.isValid) {
    throw new Error(`Invalid household timezone: ${timezone}`);
  }

  const [hourRaw, minuteRaw] = rule.sendTime.split(':');
  const hour = Number(hourRaw);
  const minute = Number(minuteRaw);
  if (!Number.isInteger(hour) || !Number.isInteger(minute) ||
      hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    throw new Error(`Invalid rule send time: ${rule.sendTime}`);
  }

  let scheduled = localNow.startOf('day').set({hour, minute, second: 0, millisecond: 0});
  if (scheduled > localNow) {
    const previous = scheduled.minus({days: 1});
    const previousDelta = localNow.diff(previous, 'minutes').minutes;
    if (previousDelta >= 0 && previousDelta < windowMinutes) {
      scheduled = previous;
    }
  }

  const delta = localNow.diff(scheduled, 'minutes').minutes;
  const due = rule.enabled && delta >= 0 && delta < windowMinutes;
  const localSendDate = scheduled.toISODate();
  if (localSendDate == null) throw new Error('Could not resolve local send date');
  const expiryDate = scheduled.plus({days: rule.daysBefore}).toISODate();
  if (expiryDate == null) throw new Error('Could not resolve expiry date');

  return {due, localSendDate, expiryDate};
}

export function renderTemplate(
  template: string,
  item: ReminderItemData,
  daysBefore: number,
): string {
  const rendered = template
    .replaceAll('{item}', item.name)
    .replaceAll('{days}', String(daysBefore))
    .replaceAll('{expiry_date}', item.expiryDate)
    .replaceAll('{quantity}', String(item.quantity))
    .replaceAll('{location}', item.location ?? '');

  // Existing user-authored templates may contain "{days} days". Preserve the
  // template language while fixing the grammatically incorrect one-day case.
  return daysBefore === 1 ? rendered.replace(/\b1 days\b/g, '1 day') : rendered;
}

export function deliveryId(
  householdId: string,
  itemId: string,
  ruleId: string,
  expiryDate: string,
  recipientUid: string,
): string {
  return [householdId, itemId, ruleId, expiryDate, recipientUid].join('__');
}
