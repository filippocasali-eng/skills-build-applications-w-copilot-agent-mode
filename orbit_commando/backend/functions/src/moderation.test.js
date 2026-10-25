const test = require('node:test');
const assert = require('node:assert');
const { check, chatRights } = require('./moderation');

test('filters insults, leetspeak and spaced-out words', () => {
  assert.equal(check('ciao a tutti').allowed, true);
  assert.equal(check('sei uno str0nz0').allowed, false);
  assert.equal(check('c a z z o').allowed, false);
});

test('blocks personal data and links', () => {
  assert.equal(check('chiamami al 333 123 4567').reason, 'phone');
  assert.equal(check('scrivi a a.b@c.it').reason, 'email');
  assert.equal(check('vai su www.example.com').reason, 'link');
});

test('age rules: under 16 none, 16-17 emotes, 18+ free', () => {
  const now = new Date(Date.UTC(2026, 9, 25));
  assert.equal(chatRights({ birthYear: 2012, birthMonth: 1 }, now), 'none');
  assert.equal(chatRights({ birthYear: 2009, birthMonth: 1 }, now), 'emotes');
  assert.equal(chatRights({ birthYear: 2000, birthMonth: 1 }, now), 'free');
  assert.equal(chatRights(undefined, now), 'none');
});
