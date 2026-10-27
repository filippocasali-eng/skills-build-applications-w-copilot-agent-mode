import { createHmac, randomBytes, randomUUID, timingSafeEqual } from "node:crypto";

/**
 * Guest identity: an httpOnly cookie "<uuid>.<hmac>" signed with GUEST_COOKIE_SECRET.
 * The signature stops clients from forging another guest's id to read their matches.
 */
export const GUEST_COOKIE = "bq_guest";
export const GUEST_COOKIE_MAX_AGE = 60 * 60 * 24 * 180;

let devSecret: string | null = null;

function secret(): string {
  const configured = process.env.GUEST_COOKIE_SECRET;
  if (configured && configured.length >= 32) return configured;
  if (process.env.NODE_ENV === "production" && process.env.BATTLEQUIZ_ALLOW_MEMORY_STORE !== "true") {
    throw new Error("GUEST_COOKIE_SECRET (>= 32 chars) is required in production");
  }
  // Development only: an ephemeral secret, so guest cookies reset on server restart.
  devSecret ??= randomBytes(32).toString("hex");
  return devSecret;
}

function sign(id: string): string {
  return createHmac("sha256", secret()).update(`guest:${id}`).digest("base64url");
}

export function issueGuestToken(): { id: string; token: string } {
  const id = randomUUID();
  return { id, token: `${id}.${sign(id)}` };
}

/** Returns the guest id when the token is authentic, otherwise null. */
export function verifyGuestToken(token: string | undefined | null): string | null {
  if (!token) return null;
  const dot = token.indexOf(".");
  if (dot <= 0) return null;
  const id = token.slice(0, dot);
  if (!/^[0-9a-f-]{36}$/.test(id)) return null;
  const given = Buffer.from(token.slice(dot + 1));
  const expected = Buffer.from(sign(id));
  if (given.length !== expected.length || !timingSafeEqual(given, expected)) return null;
  return id;
}

export const guestPlayerKey = (id: string) => `guest:${id}`;
