import type { NextRequest } from "next/server";
import { startDailyChallenge, startQuickPlay } from "@/features/gameplay/service";
import { apiError, checkRate, ensureGuest, handleError, json, parseBody, sameOrigin } from "@/lib/http";
import { RATE_LIMITS } from "@/lib/security/rate-limit";
import { getRepositories } from "@/lib/store";
import { CreateMatchSchema } from "@/lib/validation/api";

/** Starts a guest Quick Play or Daily Challenge match and returns the first question (without its answer). */
export async function POST(req: NextRequest) {
  if (!sameOrigin(req)) return apiError("FORBIDDEN", "Cross-site request rejected", 403);
  const limited = checkRate(req, "match:create", RATE_LIMITS.createMatch);
  if (limited) return limited;
  const body = await parseBody(req, CreateMatchSchema);
  if (body instanceof Response) return body;

  try {
    const guest = ensureGuest(req);
    const base = { playerKey: guest.playerKey, locale: body.locale, now: Date.now() };
    const result =
      body.mode === "daily_challenge"
        ? await startDailyChallenge(getRepositories(), base)
        : await startQuickPlay(getRepositories(), { ...base, category: body.category });
    const res = json(result, 201);
    guest.setCookie?.(res);
    return res;
  } catch (err) {
    return handleError(err);
  }
}
