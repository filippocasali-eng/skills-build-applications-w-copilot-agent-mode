import type { NextRequest } from "next/server";
import { availableCategories } from "@/features/gameplay/service";
import { checkRate, handleError, json } from "@/lib/http";
import { RATE_LIMITS } from "@/lib/security/rate-limit";
import { getRepositories } from "@/lib/store";
import { LocaleSchema } from "@/lib/validation/api";

/** Categories with enough approved questions for a full Quick Play match. */
export async function GET(req: NextRequest) {
  const limited = checkRate(req, "categories", RATE_LIMITS.read);
  if (limited) return limited;
  const locale = LocaleSchema.catch("it").parse(req.nextUrl.searchParams.get("locale"));
  try {
    return json({ categories: await availableCategories(getRepositories(), locale) });
  } catch (err) {
    return handleError(err);
  }
}
