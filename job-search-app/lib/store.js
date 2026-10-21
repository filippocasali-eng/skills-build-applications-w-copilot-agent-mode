'use strict';

const path = require('node:path');
const fs = require('node:fs');
const { PROVIDERS } = require('./providers');

const CACHE_TTL_MS = 10 * 60 * 1000;
const SAMPLE_FILE = path.join(__dirname, '..', 'data', 'sample-jobs.json');

function loadSampleJobs(now = Date.now()) {
  const raw = JSON.parse(fs.readFileSync(SAMPLE_FILE, 'utf8'));
  // Sample dates are stored as "days ago" so the demo data never looks stale.
  return raw.map((job) => ({
    ...job,
    publishedAt: new Date(now - job.daysAgo * 86_400_000).toISOString(),
    daysAgo: undefined,
  }));
}

function createJobStore({ providers = PROVIDERS, fetchImpl = fetch, ttlMs = CACHE_TTL_MS, useLive = true } = {}) {
  let cache = null;
  let inflight = null;

  async function refresh() {
    if (!useLive) {
      return { jobs: loadSampleJobs(), fetchedAt: Date.now(), fallback: true, errors: [] };
    }
    const settled = await Promise.allSettled(providers.map((p) => p.fetch(fetchImpl)));
    const errors = [];
    const jobs = [];
    settled.forEach((result, i) => {
      if (result.status === 'fulfilled') jobs.push(...result.value);
      else errors.push({ source: providers[i].name, message: result.reason?.message || String(result.reason) });
    });

    if (jobs.length === 0) {
      return { jobs: loadSampleJobs(), fetchedAt: Date.now(), fallback: true, errors };
    }

    const seen = new Set();
    const unique = jobs.filter((j) => j.url && !seen.has(j.id) && seen.add(j.id));
    return { jobs: unique, fetchedAt: Date.now(), fallback: false, errors };
  }

  async function getJobs() {
    if (cache && Date.now() - cache.fetchedAt < ttlMs) return cache;
    // Concurrent requests share one upstream refresh.
    if (!inflight) {
      inflight = refresh()
        .then((result) => {
          // A fallback result is cached briefly so a provider outage doesn't hammer upstream nor stick for 10 minutes.
          cache = result.fallback ? { ...result, fetchedAt: Date.now() - ttlMs + 60_000 } : result;
          return result;
        })
        .finally(() => {
          inflight = null;
        });
    }
    return inflight;
  }

  return { getJobs };
}

module.exports = { createJobStore, loadSampleJobs };
