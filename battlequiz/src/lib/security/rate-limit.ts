/**
 * Fixed-window rate limiter kept in process memory. It protects a single
 * server instance; on multi-instance deployments add a shared limiter
 * (e.g. Vercel firewall rules or a Postgres/Redis-backed counter). See SECURITY.md.
 */
export interface RateLimitRule {
  limit: number;
  windowMs: number;
}

export const RATE_LIMITS = {
  createMatch: { limit: 20, windowMs: 60_000 },
  answer: { limit: 90, windowMs: 60_000 },
  read: { limit: 240, windowMs: 60_000 },
} satisfies Record<string, RateLimitRule>;

export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  retryAfterMs: number;
}

export function createRateLimiter(now: () => number = Date.now) {
  const buckets = new Map<string, { start: number; count: number }>();
  let lastSweep = now();

  return function check(key: string, rule: RateLimitRule): RateLimitResult {
    const t = now();
    if (t - lastSweep > 60_000) {
      for (const [k, b] of buckets) if (t - b.start >= rule.windowMs * 2) buckets.delete(k);
      lastSweep = t;
    }
    let bucket = buckets.get(key);
    if (!bucket || t - bucket.start >= rule.windowMs) {
      bucket = { start: t, count: 0 };
      buckets.set(key, bucket);
    }
    bucket.count++;
    const allowed = bucket.count <= rule.limit;
    return {
      allowed,
      remaining: Math.max(0, rule.limit - bucket.count),
      retryAfterMs: allowed ? 0 : rule.windowMs - (t - bucket.start),
    };
  };
}

const globalLimiter = globalThis as unknown as { __bqLimiter?: ReturnType<typeof createRateLimiter> };
export const rateLimit = (globalLimiter.__bqLimiter ??= createRateLimiter());
