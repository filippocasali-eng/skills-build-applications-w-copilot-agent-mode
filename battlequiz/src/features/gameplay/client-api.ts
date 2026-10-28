import type { AnswerFeedback, CategorySelection, Locale, MatchResults, PublicQuestion, QuestionCategory } from "@/types/game";
import { ApiError } from "./client-api-error";
import type { MatchSnapshot } from "./service";

export { ApiError };

/** True in the Android app build, where the game runs on-device without a server. */
export const OFFLINE_MODE = process.env.NEXT_PUBLIC_BQ_OFFLINE === "1";

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

/** Typed browser client for the gameplay HTTP API. */
const httpGameApi = {
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

type GameApi = typeof httpGameApi;

/** Lazily loads the on-device engine only in the offline build. */
const lazyLocal = <K extends keyof GameApi>(key: K): GameApi[K] =>
  (async (...args: unknown[]) => {
    const { localGameApi } = await import("./local-api");
    return (localGameApi[key] as (...a: unknown[]) => unknown)(...args);
  }) as GameApi[K];

export const gameApi: GameApi = OFFLINE_MODE
  ? {
      categories: lazyLocal("categories"),
      start: lazyLocal("start"),
      current: lazyLocal("current"),
      answer: lazyLocal("answer"),
      results: lazyLocal("results"),
    }
  : httpGameApi;
