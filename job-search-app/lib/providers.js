'use strict';

const { htmlToText } = require('./text');

const FETCH_TIMEOUT_MS = 10_000;
const ARBEITNOW_PAGES = 3;

const JOB_TYPE_LABELS = {
  full_time: 'Full-time',
  'full-time': 'Full-time',
  'full time': 'Full-time',
  part_time: 'Part-time',
  'part-time': 'Part-time',
  'part time': 'Part-time',
  contract: 'Contratto',
  freelance: 'Freelance',
  internship: 'Stage',
  'working student': 'Stage',
  temporary: 'Temporaneo',
  other: 'Altro',
};

function normalizeJobType(raw) {
  const key = String(raw || '').trim().toLowerCase();
  if (!key) return null;
  if (JOB_TYPE_LABELS[key]) return JOB_TYPE_LABELS[key];
  if (key.includes('intern') || key.includes('stage') || key.includes('trainee')) return 'Stage';
  if (key.includes('part')) return 'Part-time';
  if (key.includes('full') || key.includes('permanent')) return 'Full-time';
  if (key.includes('contract') || key.includes('freelance')) return 'Contratto';
  return 'Altro';
}

async function fetchJson(url, fetchImpl) {
  const res = await fetchImpl(url, {
    headers: { Accept: 'application/json', 'User-Agent': 'job-search-app/1.0' },
    signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status} da ${new URL(url).host}`);
  return res.json();
}

function mapArbeitnow(job) {
  const types = [...new Set((job.job_types || []).map(normalizeJobType).filter(Boolean))];
  return {
    id: `arbeitnow:${job.slug}`,
    source: 'Arbeitnow',
    title: job.title || '',
    company: job.company_name || '',
    location: job.location || (job.remote ? 'Remoto' : ''),
    remote: Boolean(job.remote),
    types,
    tags: Array.isArray(job.tags) ? job.tags : [],
    salary: null,
    url: job.url,
    description: htmlToText(job.description),
    publishedAt: job.created_at ? new Date(job.created_at * 1000).toISOString() : null,
  };
}

function mapRemotive(job) {
  const type = normalizeJobType(job.job_type);
  return {
    id: `remotive:${job.id}`,
    source: 'Remotive',
    title: job.title || '',
    company: job.company_name || '',
    location: job.candidate_required_location ? `Remoto (${job.candidate_required_location})` : 'Remoto',
    remote: true,
    types: type ? [type] : [],
    tags: [job.category, ...(Array.isArray(job.tags) ? job.tags : [])].filter(Boolean),
    salary: job.salary || null,
    url: job.url,
    description: htmlToText(job.description),
    publishedAt: job.publication_date ? new Date(job.publication_date).toISOString() : null,
  };
}

async function fetchArbeitnow(fetchImpl = fetch) {
  const pages = await Promise.allSettled(
    Array.from({ length: ARBEITNOW_PAGES }, (_, i) =>
      fetchJson(`https://www.arbeitnow.com/api/job-board-api?page=${i + 1}`, fetchImpl)
    )
  );
  const ok = pages.filter((p) => p.status === 'fulfilled');
  if (ok.length === 0) throw pages[0].reason;
  return ok.flatMap((p) => (p.value.data || []).map(mapArbeitnow));
}

async function fetchRemotive(fetchImpl = fetch) {
  const body = await fetchJson('https://remotive.com/api/remote-jobs?limit=150', fetchImpl);
  return (body.jobs || []).map(mapRemotive);
}

const PROVIDERS = [
  { name: 'Arbeitnow', fetch: fetchArbeitnow },
  { name: 'Remotive', fetch: fetchRemotive },
];

module.exports = { PROVIDERS, mapArbeitnow, mapRemotive, normalizeJobType };
