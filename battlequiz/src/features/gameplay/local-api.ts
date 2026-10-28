import { createMemoryRepositories } from "@/lib/store/memory";
import type { Repositories } from "@/lib/store/types";
import type { CategorySelection, GameMode, Locale } from "@/types/game";
import { ApiError } from "./client-api-error";
import { answerQuestion, availableCategories, GameServiceError, getCurrentQuestion, getResults, startDailyChallenge, startQuickPlay } from "./service";

/**
 * OFFLINE MODE (Android app build). The same tested game engine runs on the
 * device against the bundled question bank, so no server is needed. Scores are
 * local and unranked: a device cannot be trusted for competitive results, so
 * ranked modes will always go through the server.
 */
const PLAYER = "local:device";
const HISTORY_KEY = "bq-offline-history";

function loadHistory(): string[] {
  try {
    return JSON.parse(localStorage.getItem(HISTORY_KEY) ?? "[]");
  } catch {
    return [];
  }
}

let repos: Repositories | null = null;

function getRepos(): Repositories {
  if (repos) return repos;
  const base = createMemoryRepositories();
  // Persist "recently seen" so questions don't repeat across app restarts.
  repos = {
    ...base,
    history: {
      async recent(_player, limit) {
        return loadHistory().slice(0, limit);
      },
      async record(_player, ids) {
        try {
          const merged = [...[...ids].reverse(), ...loadHistory().filter((id) => !ids.includes(id))].slice(0, 300);
          localStorage.setItem(HISTORY_KEY, JSON.stringify(merged));
        } catch {
          // Storage unavailable: repetition control falls back to this session only.
        }
      },
    },
  };
  return repos;
}

async function call<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (err) {
    if (err instanceof GameServiceError) throw new ApiError(err.code, err.status, err.message);
    throw new ApiError("UNKNOWN", 500, err instanceof Error ? err.message : "Unknown error");
  }
}

export const localGameApi = {
  categories: (locale: Locale) => call(async () => ({ categories: await availableCategories(getRepos(), locale) })),
  start: (locale: Locale, category: CategorySelection, mode: GameMode = "quick_play") =>
    call(() =>
      mode === "daily_challenge"
        ? startDailyChallenge(getRepos(), { playerKey: PLAYER, locale, now: Date.now() })
        : startQuickPlay(getRepos(), { playerKey: PLAYER, locale, category, now: Date.now() }),
    ),
  current: (matchId: string) => call(() => getCurrentQuestion(getRepos(), { matchId, playerKey: PLAYER, now: Date.now() })),
  answer: (matchId: string, questionIndex: number, selectedIndex: number | null) =>
    call(() => answerQuestion(getRepos(), { matchId, playerKey: PLAYER, questionIndex, selectedIndex, now: Date.now() })),
  results: (matchId: string) => call(() => getResults(getRepos(), { matchId, playerKey: PLAYER })),
};
