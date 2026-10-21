'use strict';

const { normalize } = require('./text');

const PAGE_SIZE = 20;
const MAX_PAGE_SIZE = 50;

function parseQuery(params) {
  const get = (key) => (params.get(key) || '').trim();
  const page = Math.max(1, parseInt(get('page'), 10) || 1);
  const pageSize = Math.min(MAX_PAGE_SIZE, Math.max(1, parseInt(get('pageSize'), 10) || PAGE_SIZE));
  return {
    q: get('q'),
    location: get('location'),
    remote: get('remote') === 'true',
    types: get('types') ? get('types').split(',').map((t) => t.trim()).filter(Boolean) : [],
    sources: get('sources') ? get('sources').split(',').map((s) => s.trim()).filter(Boolean) : [],
    maxAgeDays: Math.max(0, parseInt(get('maxAgeDays'), 10) || 0),
    sort: get('sort') === 'date' ? 'date' : 'relevance',
    page,
    pageSize,
  };
}

function scoreJob(job, terms) {
  if (terms.length === 0) return 1;
  const title = normalize(job.title);
  const company = normalize(job.company);
  const tags = normalize(job.tags.join(' '));
  const description = normalize(job.description);
  let score = 0;
  for (const term of terms) {
    let termScore = 0;
    if (title.includes(term)) termScore += 10;
    if (tags.includes(term)) termScore += 5;
    if (company.includes(term)) termScore += 4;
    if (description.includes(term)) termScore += 1;
    // Every term must appear somewhere: "react milano" shouldn't match a Java job in Rome.
    if (termScore === 0) return 0;
    score += termScore;
  }
  return score;
}

function searchJobs(jobs, query, now = Date.now()) {
  const terms = normalize(query.q).split(/\s+/).filter(Boolean);
  const location = normalize(query.location);
  const minDate = query.maxAgeDays ? now - query.maxAgeDays * 86_400_000 : 0;

  const matches = [];
  for (const job of jobs) {
    if (query.remote && !job.remote) continue;
    if (location && !normalize(job.location).includes(location)) continue;
    if (query.types.length && !job.types.some((t) => query.types.includes(t))) continue;
    if (query.sources.length && !query.sources.includes(job.source)) continue;
    if (minDate && (!job.publishedAt || Date.parse(job.publishedAt) < minDate)) continue;
    const score = scoreJob(job, terms);
    if (score > 0) matches.push({ job, score });
  }

  const byDate = (a, b) => (Date.parse(b.job.publishedAt) || 0) - (Date.parse(a.job.publishedAt) || 0);
  matches.sort(query.sort === 'date' ? byDate : (a, b) => b.score - a.score || byDate(a, b));

  const total = matches.length;
  const totalPages = Math.max(1, Math.ceil(total / query.pageSize));
  const page = Math.min(query.page, totalPages);
  const start = (page - 1) * query.pageSize;

  return {
    total,
    page,
    totalPages,
    pageSize: query.pageSize,
    results: matches.slice(start, start + query.pageSize).map((m) => m.job),
    facets: buildFacets(jobs),
  };
}

function buildFacets(jobs) {
  const count = (values) => {
    const map = new Map();
    for (const v of values) map.set(v, (map.get(v) || 0) + 1);
    return [...map.entries()].sort((a, b) => b[1] - a[1]).map(([value, n]) => ({ value, count: n }));
  };
  return {
    types: count(jobs.flatMap((j) => j.types)),
    sources: count(jobs.map((j) => j.source)),
  };
}

module.exports = { parseQuery, searchJobs, scoreJob };
