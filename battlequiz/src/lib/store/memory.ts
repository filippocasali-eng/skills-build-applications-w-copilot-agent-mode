import { loadSeedQuestions } from "@/features/questions/bank";
import { QUESTION_CATEGORIES, type Locale, type MatchState, type Question, type QuestionCategory } from "@/types/game";
import type { Repositories } from "./types";

/**
 * LOCAL DEVELOPMENT MODE store. Data lives in process memory and is lost on
 * restart; it is not shared between server instances. Used automatically when
 * DATABASE_URL is not set. Never use it for production traffic.
 */
export function createMemoryRepositories(questions: readonly Question[] = loadSeedQuestions()): Repositories {
  const byId = new Map(questions.map((q) => [q.id, q]));
  const matches = new Map<string, MatchState>();
  const history = new Map<string, Map<string, number>>();
  const auditLog: unknown[] = [];

  const playable = (locale: Locale) => questions.filter((q) => q.locale === locale && q.reviewStatus === "approved");

  return {
    kind: "memory",
    questions: {
      async listPlayable(locale) {
        return playable(locale);
      },
      async getByIds(ids) {
        const out = new Map<string, Question>();
        for (const id of ids) {
          const q = byId.get(id);
          if (q) out.set(id, q);
        }
        return out;
      },
      async countByCategory(locale) {
        const counts = Object.fromEntries(QUESTION_CATEGORIES.map((c) => [c, 0])) as Record<QuestionCategory, number>;
        for (const q of playable(locale)) counts[q.category]++;
        return counts;
      },
    },
    matches: {
      async create(state) {
        if (matches.has(state.id)) throw new Error("Match already exists");
        matches.set(state.id, structuredClone(state));
      },
      async get(id) {
        const m = matches.get(id);
        return m ? structuredClone(m) : null;
      },
      async save(next, expectedVersion) {
        const current = matches.get(next.id);
        if (!current || current.version !== expectedVersion) return false;
        matches.set(next.id, structuredClone({ ...next, version: expectedVersion + 1 }));
        return true;
      },
    },
    history: {
      async recent(playerKey, limit) {
        const seen = history.get(playerKey);
        if (!seen) return [];
        return [...seen.entries()]
          .sort((a, b) => b[1] - a[1])
          .slice(0, limit)
          .map(([id]) => id);
      },
      async record(playerKey, ids, at) {
        let seen = history.get(playerKey);
        if (!seen) history.set(playerKey, (seen = new Map()));
        ids.forEach((id, i) => seen.set(id, at + i));
      },
    },
    audit: {
      async log(event) {
        auditLog.push({ ...event, at: Date.now() });
        if (auditLog.length > 1000) auditLog.shift();
      },
    },
  };
}
