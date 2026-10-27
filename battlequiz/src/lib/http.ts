import "server-only";
import { NextResponse, type NextRequest } from "next/server";
import type { z } from "zod";
import { GameServiceError } from "@/features/gameplay/service";
import { GUEST_COOKIE, GUEST_COOKIE_MAX_AGE, guestPlayerKey, issueGuestToken, verifyGuestToken } from "@/lib/security/guest";
import { rateLimit, type RateLimitRule } from "@/lib/security/rate-limit";

export interface ApiErrorBody {
  error: { code: string; message: string };
}

const NO_STORE = { "Cache-Control": "no-store" };

export function json<T>(body: T, status = 200, headers: Record<string, string> = {}): NextResponse {
  return NextResponse.json(body, { status, headers: { ...NO_STORE, ...headers } });
}

export function apiError(code: string, message: string, status: number, headers: Record<string, string> = {}) {
  return json<ApiErrorBody>({ error: { code, message } }, status, headers);
}

export function clientIp(req: NextRequest): string {
  return req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || req.headers.get("x-real-ip") || "unknown";
}

/**
 * Rejects cross-site state-changing requests. Combined with SameSite=Lax cookies
 * this is the CSRF protection for cookie-authenticated POST endpoints.
 */
export function sameOrigin(req: NextRequest): boolean {
  const origin = req.headers.get("origin");
  if (!origin) return req.headers.get("sec-fetch-site") !== "cross-site";
  try {
    return new URL(origin).host === (req.headers.get("x-forwarded-host") ?? req.headers.get("host"));
  } catch {
    return false;
  }
}

export function checkRate(req: NextRequest, bucket: string, rule: RateLimitRule): NextResponse | null {
  const r = rateLimit(`${bucket}:${clientIp(req)}`, rule);
  if (r.allowed) return null;
  return apiError("RATE_LIMITED", "Too many requests", 429, { "Retry-After": String(Math.ceil(r.retryAfterMs / 1000)) });
}

/** Existing guest identity from the signed cookie, if any. */
export function readGuest(req: NextRequest): string | null {
  const id = verifyGuestToken(req.cookies.get(GUEST_COOKIE)?.value);
  return id ? guestPlayerKey(id) : null;
}

/** Returns the caller's guest player key, minting a new signed cookie when needed. */
export function ensureGuest(req: NextRequest): { playerKey: string; setCookie: ((res: NextResponse) => void) | null } {
  const existing = readGuest(req);
  if (existing) return { playerKey: existing, setCookie: null };
  const { id, token } = issueGuestToken();
  return {
    playerKey: guestPlayerKey(id),
    setCookie: (res) =>
      res.cookies.set(GUEST_COOKIE, token, {
        httpOnly: true,
        sameSite: "lax",
        secure: process.env.NODE_ENV === "production",
        path: "/",
        maxAge: GUEST_COOKIE_MAX_AGE,
      }),
  };
}

export async function parseBody<S extends z.ZodType>(req: NextRequest, schema: S): Promise<z.infer<S> | NextResponse> {
  let raw: unknown;
  try {
    raw = await req.json();
  } catch {
    return apiError("BAD_REQUEST", "Invalid JSON body", 400);
  }
  const parsed = schema.safeParse(raw);
  if (!parsed.success) return apiError("VALIDATION_FAILED", parsed.error.issues[0]?.message ?? "Invalid input", 400);
  return parsed.data;
}

/** Maps domain errors to HTTP responses without leaking internals. */
export function handleError(err: unknown): NextResponse {
  if (err instanceof GameServiceError) return apiError(err.code, err.message, err.status);
  console.error("[battlequiz] unexpected error", err instanceof Error ? err.message : err);
  return apiError("INTERNAL", "Something went wrong", 500);
}
