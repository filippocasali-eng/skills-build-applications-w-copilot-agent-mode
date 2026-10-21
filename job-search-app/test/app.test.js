'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { htmlToText, normalize } = require('../lib/text');
const { parseQuery, searchJobs } = require('../lib/search');
const { mapArbeitnow, mapRemotive, normalizeJobType } = require('../lib/providers');
const { createJobStore, loadSampleJobs } = require('../lib/store');
const { createServer } = require('../server');

const jobs = loadSampleJobs();
const query = (qs) => parseQuery(new URLSearchParams(qs));

test('htmlToText strips markup, scripts and decodes entities', () => {
  const html = '<p>Ciao&nbsp;<b>mondo</b> &amp; co.</p><script>alert(1)</script><ul><li>Uno</li><li>Due</li></ul>';
  assert.equal(htmlToText(html), 'Ciao mondo & co.\n\n• Uno\n• Due');
  assert.equal(htmlToText('<img src=x onerror=alert(1)>Testo'), 'Testo');
});

test('normalize removes accents and case', () => {
  assert.equal(normalize('Città PERÒ'), 'citta pero');
});

test('normalizeJobType maps provider values to Italian labels', () => {
  assert.equal(normalizeJobType('full_time'), 'Full-time');
  assert.equal(normalizeJobType('Internship'), 'Stage');
  assert.equal(normalizeJobType('Berufserfahren'), 'Altro');
  assert.equal(normalizeJobType(''), null);
});

test('keyword search requires every term and ranks title matches first', () => {
  const res = searchJobs(jobs, query('q=python'));
  assert.ok(res.total >= 2);
  assert.match(res.results[0].title, /python/i);
  assert.ok(res.results.every((j) => normalize(`${j.title} ${j.tags} ${j.description}`).includes('python')));

  assert.equal(searchJobs(jobs, query('q=react venezia')).total, 0);
});

test('filters: location, remote, types, sources, age', () => {
  assert.ok(searchJobs(jobs, query('location=milano')).results.every((j) => j.location === 'Milano'));
  assert.ok(searchJobs(jobs, query('remote=true')).results.every((j) => j.remote));
  assert.ok(searchJobs(jobs, query('types=Stage')).results.every((j) => j.types.includes('Stage')));
  assert.equal(searchJobs(jobs, query('sources=Altro')).total, 0);
  const recent = searchJobs(jobs, query('maxAgeDays=3&pageSize=50'));
  assert.ok(recent.total > 0 && recent.total < jobs.length);
});

test('sort by date and pagination', () => {
  const res = searchJobs(jobs, query('sort=date&pageSize=5&page=2'));
  assert.equal(res.page, 2);
  assert.equal(res.results.length, 5);
  const dates = res.results.map((j) => Date.parse(j.publishedAt));
  assert.deepEqual(dates, [...dates].sort((a, b) => b - a));

  const clamped = searchJobs(jobs, query('page=999'));
  assert.equal(clamped.page, clamped.totalPages);
});

test('provider mappers produce the common job shape', () => {
  const a = mapArbeitnow({
    slug: 'dev-123', company_name: 'ACME', title: 'Dev', description: '<p>Hi</p>', remote: true,
    url: 'https://x.test/1', tags: ['js'], job_types: ['full time'], location: 'Berlin', created_at: 1_700_000_000,
  });
  assert.equal(a.id, 'arbeitnow:dev-123');
  assert.deepEqual(a.types, ['Full-time']);
  assert.equal(a.description, 'Hi');

  const r = mapRemotive({
    id: 9, url: 'https://x.test/2', title: 'Designer', company_name: 'Co', category: 'Design', tags: ['figma'],
    job_type: 'contract', publication_date: '2026-10-01T10:00:00', candidate_required_location: 'Europe', salary: '50k', description: '',
  });
  assert.equal(r.location, 'Remoto (Europe)');
  assert.deepEqual(r.tags, ['Design', 'figma']);
  assert.equal(r.remote, true);
});

test('store falls back to demo jobs when every provider fails, and keeps partial results otherwise', async () => {
  const failing = { name: 'Down', fetch: async () => { throw new Error('boom'); } };
  const working = { name: 'Up', fetch: async () => [{ ...jobs[0], id: 'up:1' }, { ...jobs[0], id: 'up:1' }] };

  const allDown = await createJobStore({ providers: [failing] }).getJobs();
  assert.equal(allDown.fallback, true);
  assert.equal(allDown.errors[0].source, 'Down');
  assert.equal(allDown.jobs.length, jobs.length);

  const partial = await createJobStore({ providers: [failing, working] }).getJobs();
  assert.equal(partial.fallback, false);
  assert.equal(partial.jobs.length, 1, 'duplicates are removed');
});

test('store shares one upstream refresh between concurrent requests', async () => {
  let calls = 0;
  const provider = { name: 'P', fetch: async () => { calls++; return [jobs[0]]; } };
  const store = createJobStore({ providers: [provider] });
  await Promise.all([store.getJobs(), store.getJobs(), store.getJobs()]);
  await store.getJobs();
  assert.equal(calls, 1);
});

test('HTTP server serves the API and static files, blocks path traversal', async (t) => {
  const server = createServer(createJobStore({ useLive: false }));
  await new Promise((resolve) => server.listen(0, resolve));
  t.after(() => server.close());
  const base = `http://127.0.0.1:${server.address().port}`;

  const api = await fetch(`${base}/api/jobs?q=developer&pageSize=3`);
  assert.equal(api.status, 200);
  const body = await api.json();
  assert.equal(body.fallback, true);
  assert.ok(body.results.length <= 3 && body.total > 0);

  const home = await fetch(`${base}/`);
  assert.equal(home.status, 200);
  assert.match(await home.text(), /Cerca Lavoro/);

  const traversal = await fetch(`${base}/%2e%2e/server.js`);
  assert.notEqual(traversal.status, 200);

  const post = await fetch(`${base}/api/jobs`, { method: 'POST' });
  assert.equal(post.status, 405);
});
