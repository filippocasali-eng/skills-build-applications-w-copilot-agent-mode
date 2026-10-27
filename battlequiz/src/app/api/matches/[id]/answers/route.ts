import type { NextRequest } from "next/server";
import { answerQuestion } from "@/features/gameplay/service";
import { apiError, checkRate, handleError, json, parseBody, readGuest, sameOrigin } from "@/lib/http";
import { RATE_LIMITS } from "@/lib/security/rate-limit";
import { getRepositories } from "@/lib/store";
import { MatchIdSchema, SubmitAnswerSchema } from "@/lib/validation/api";

/** Submits an answer. Scoring uses server time only; resubmissions are idempotent. */
export async function POST(req: NextRequest, ctx: RouteContext<"/api/matches/[id]/answers">) {
  const now = Date.now();
  if (!sameOrigin(req)) return apiError("FORBIDDEN", "Cross-site request rejected", 403);
  const limited = checkRate(req, "match:answer", RATE_LIMITS.answer);
  if (limited) return limited;
  const { id } = await ctx.params;
  const playerKey = readGuest(req);
  if (!playerKey || !MatchIdSchema.safeParse(id).success) return apiError("NOT_FOUND", "Match not found", 404);
  const body = await parseBody(req, SubmitAnswerSchema);
  if (body instanceof Response) return body;
  try {
    return json(await answerQuestion(getRepositories(), { matchId: id, playerKey, ...body, now }));
  } catch (err) {
    return handleError(err);
  }
}
