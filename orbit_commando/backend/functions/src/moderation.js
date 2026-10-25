// Server-side chat moderation. Mirrors lib/core/social/moderation.dart; the
// server list is the authoritative one and can be longer (load extra words
// from Firestore `config/moderation.words` at cold start).

const BASE_WORDS = [
  // en
  'fuck', 'shit', 'bitch', 'bastard', 'asshole', 'dick', 'cunt', 'slut',
  'whore', 'retard', 'faggot', 'nigger',
  // it
  'cazzo', 'stronzo', 'stronza', 'vaffanculo', 'fanculo', 'puttana', 'troia',
  'coglione', 'merda', 'bastardo', 'frocio', 'negro', 'mongoloide', 'ritardato',
];

const LEET = {
  0: 'o', 1: 'i', 3: 'e', 4: 'a', 5: 's', 7: 't', '@': 'a', $: 's',
  à: 'a', è: 'e', é: 'e', ì: 'i', ò: 'o', ù: 'u',
};

const PHONE = /(\+?\d[\d\s\-.()]{6,}\d)/;
const EMAIL = /[\w.+-]+@[\w-]+\.[\w.]+/i;
const LINK = /(https?:\/\/|www\.|\b[\w-]+\.(com|it|net|org|io|gg|ly|me|tv|xyz)\b)/i;

/** Quick messages allowed for 16-17 year olds (EN + IT client strings). */
const EMOTES = new Set([
  'Nice shot!', 'Help with the boss?', 'GG', 'Hi!', 'Thanks!', 'One more!',
  'Bel colpo!', 'Aiuto col boss?', 'Ciao!', 'Grazie!', 'Ancora una!',
]);

function normalize(text) {
  let out = '';
  for (const ch of text.toLowerCase()) out += LEET[ch] ?? ch;
  // Drop separators used to dodge filters: "f.u.c.k", "c a z z o".
  return out.replace(/[\s._\-*]+/g, '');
}

/**
 * @returns {{allowed: boolean, reason?: string}}
 */
function check(text, { maxLength = 140, extraWords = [] } = {}) {
  const t = (text ?? '').trim();
  if (!t) return { allowed: false, reason: 'empty' };
  if (t.length > maxLength) return { allowed: false, reason: 'length' };
  if (PHONE.test(t)) return { allowed: false, reason: 'phone' };
  if (EMAIL.test(t)) return { allowed: false, reason: 'email' };
  if (LINK.test(t)) return { allowed: false, reason: 'link' };
  const n = normalize(t);
  for (const w of [...BASE_WORDS, ...extraWords]) {
    if (n.includes(w)) return { allowed: false, reason: 'word' };
  }
  return { allowed: true };
}

/** Age in whole years at `now` from birth year + month (1-12). */
function ageAt(birthYear, birthMonth, now = new Date()) {
  if (!birthYear || !birthMonth) return 0;
  let age = now.getUTCFullYear() - birthYear;
  if (now.getUTCMonth() + 1 < birthMonth) age--;
  return age;
}

/**
 * What a user may post: 'none' (under 16 or unknown), 'emotes' (16-17),
 * 'free' (18+).
 */
function chatRights(profile, now = new Date()) {
  const age = ageAt(profile?.birthYear, profile?.birthMonth, now);
  if (age < 16) return 'none';
  if (age < 18) return 'emotes';
  return 'free';
}

module.exports = { check, normalize, ageAt, chatRights, EMOTES };
