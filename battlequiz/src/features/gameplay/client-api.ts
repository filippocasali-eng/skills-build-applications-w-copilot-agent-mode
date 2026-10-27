import type { AnswerFeedback, CategorySelection, Locale, MatchResults, PublicQuestion, QuestionCategory } from "@/types/game";
import type { MatchSnapshot } from "./service";

/** Typed browser client for the gameplay API. */
export class ApiError extends Error {
  constructor(
    public readonly code: string,
    public readonly status: number,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

async function request<T>(url: string, init?: RequestInit): Promise<T> {
  let res: Response;
  try {
    res = await fetch(url, {
      ...init,
      credentials: "same-origin",
      headers: { "Content-Type": "application/json", ...(init?.headers ?? {}) },
    });
  } catch {
    throw new ApiError("NETWORK", 0, "Network error");
  }
  const body = await res.json().catch(() => null);
  if (!res.ok) throw new ApiError(body?.error?.code ?? "UNKNOWN", res.status, body?.error?.message ?? res.statusText);
  return body as T;
}

/** Retries idempotent calls on network failures (answers are idempotent server-side). */
async function withRetry<T>(fn: () => Promise<T>, attempts = 3): Promise<T> {
  for (let i = 0; ; i++) {
    try {
      return await fn();
    } catch (err) {
      if (!(err instanceof ApiError) || err.code !== "NETWORK" || i >= attempts - 1) throw err;
      await new Promise((r) => setTimeout(r, 300 * 2 ** i));
    }
  }
}

export const gameApi = {
  categories: (locale: Locale) => request<{ categories: QuestionCategory[] }>(`/api/categories?locale=${locale}`),
  start: (locale: Locale, category: CategorySelection) =>
    request<{ matchId: string; question: PublicQuestion }>("/api/matches", {
      method: "POST",
      body: JSON.stringify({ locale, category }),
    }),
  current: (matchId: string) => withRetry(() => request<MatchSnapshot>(`/api/matches/${matchId}/question`)),
  answer: (matchId: string, questionIndex: number, selectedIndex: number | null) =>
    withRetry(() =>
      request<{ feedback: AnswerFeedback; completed: boolean }>(`/api/matches/${matchId}/answers`, {
        method: "POST",
        body: JSON.stringify({ questionIndex, selectedIndex }),
      }),
    ),
  results: (matchId: string) => withRetry(() => request<MatchResults>(`/api/matches/${matchId}/results`)),
};
