// Friendly daily reminders (native only). Asked for permission only after the
// player finished a game, never on first launch.

import { isNative, plugin } from './config.js';
import { S, save } from './state.js';

const MESSAGES = [
  ['Your cats miss you 🐱', 'A free Mystery Box is waiting. Come say hi!'],
  ['Daily Challenge is live 🏆', 'New board, new pieces. Can you hit the goal?'],
  ['Don’t lose your streak 🔥', 'One quick game keeps your streak alive.'],
  ['Purrfect time for a break 😺', 'Blast a few lines and grab your daily reward.'],
];

export async function askNotifications() {
  const LN = plugin('LocalNotifications');
  if (!isNative() || !LN || S.settings.notifAsked) return;
  S.settings.notifAsked = true;
  save();
  try {
    const p = await LN.requestPermissions();
    S.settings.notif = p.display === 'granted';
    save();
    if (S.settings.notif) scheduleReminders();
  } catch { /* ignore */ }
}

export async function scheduleReminders() {
  const LN = plugin('LocalNotifications');
  if (!isNative() || !LN || !S.settings.notif) return;
  try {
    await LN.cancel({ notifications: [{ id: 1 }, { id: 2 }] });
    const now = new Date();
    const at = (days, hour) => { const d = new Date(now); d.setDate(d.getDate() + days); d.setHours(hour, 7, 0, 0); return d; };
    const pick = (i) => MESSAGES[(now.getDate() + i) % MESSAGES.length];
    const [t1, b1] = pick(0);
    const [t2, b2] = pick(2);
    await LN.schedule({
      notifications: [
        { id: 1, title: t1, body: b1, schedule: { at: at(1, 19), allowWhileIdle: true } },
        { id: 2, title: t2, body: b2, schedule: { at: at(2, 18), allowWhileIdle: true } },
      ],
    });
  } catch { /* ignore */ }
}
