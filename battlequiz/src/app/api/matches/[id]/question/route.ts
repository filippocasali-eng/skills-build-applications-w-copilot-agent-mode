import type { NextRequest } from "next/server";
import { getCurrentQuestion } from "@/features/gameplay/service";
import { apiError, checkRate, handleError, json, readGuest } from "@/lib/http";
import { RATE_LIMITS } from "@/lib/security/rate-limit";
import { getRepositories } from "@/lib/store";
import { MatchIdSchema } from "@/lib/validation/api";

/** Current question of the caller's match. The first fetch starts the question timer. */
export async function GET(req: NextRequest, ctx: RouteContext<"/api/matches/[id]/question">) {
  const limited = checkRate(req, "match:read", RATE_LIMITS.read);
  if (limited) return limited;
  const { id } = await ctx.params;
  const playerKey = readGuest(req);
  if (!playerKey || !MatchIdSchema.safeParse(id).success) return apiError("NOT_FOUND", "Match not found", 404);
  try {
    return json(await getCurrentQuestion(getRepositories(), { matchId: id, playerKey, now: Date.now() }));
  } catch (err) {
    return handleError(err);
  }
}
