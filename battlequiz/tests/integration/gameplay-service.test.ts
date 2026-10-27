import { describe, expect, it } from "vitest";
import {
  answerQuestion,
  availableCategories,
  GameServiceError,
  getCurrentQuestion,
  getResults,
  startQuickPlay,
} from "@/features/gameplay/service";
import { createRng } from "@/lib/random";
import { createMemoryRepositories } from "@/lib/store/memory";
import type { Repositories } from "@/lib/store/types";
import { QUESTION_CATEGORIES } from "@/types/game";

/** Service-level tests against a repository implementation; reused for PostgreSQL in db.test.ts. */
export function gameplaySuite(name: string, makeRepos: () => Promise<Repositories> | Repositories) {
  describe(`gameplay service (${name})`, () => {
    const T0 = 1_700_000_000_000;
    const player = () => `guest:${crypto.randomUUID()}`;

    /** Server-side helper to find the right answer, standing in for a perfect player. */
    async function correctIndexOf(repos: Repositories, matchId: string) {
      const s = (await repos.matches.get(matchId))!;
      return s.questions[s.currentIndex].correctDisplayIndex;
    }

    it("plays a full 10-question match and returns results", async () => {
      const repos = await makeRepos();
      const playerKey = player();
      const { matchId, question } = await startQuickPlay(repos, { playerKey, locale: "it", category: "mixed", now: T0, rng: createRng(1) });
      expect(question.index).toBe(0);
      expect(question.total).toBe(10);
      expect(question).not.toHaveProperty("correctIndex");

      let now = T0;
      for (let i = 0; i < 10; i++) {
        const snap = await getCurrentQuestion(repos, { matchId, playerKey, now });
        expect(snap.question?.index).toBe(i);
        const sel = i % 3 === 2 ? ((await correctIndexOf(repos, matchId)) + 1) % 4 : await correctIndexOf(repos, matchId);
        now += 2_000;
        const { feedback, completed } = await answerQuestion(repos, { matchId, playerKey, questionIndex: i, selectedIndex: sel, now });
        expect(feedback.correct).toBe(i % 3 !== 2);
        expect(completed).toBe(i === 9);
        now += 1_500;
      }

      const results = await getResults(repos, { matchId, playerKey });
      expect(results.correctCount).toBe(7);
      expect(results.totalQuestions).toBe(10);
      expect(results.review).toHaveLength(10);
      expect(results.review.every((r) => r.explanation.length > 0)).toBe(true);
      expect(results.xpEarned).toBe(90);
      expect(results.score).toBeGreaterThan(0);
      expect(results.rulesetVersion).toBe("v1");

      const final = await getCurrentQuestion(repos, { matchId, playerKey, now });
      expect(final.status).toBe("COMPLETED");
      expect(final.question).toBeNull();
    });

    it("isolates players: another guest cannot read or answer the match", async () => {
      const repos = await makeRepos();
      const owner = player();
      const { matchId } = await startQuickPlay(repos, { playerKey: owner, locale: "it", category: "mixed", now: T0 });
      const intruder = player();
      await expect(getCurrentQuestion(repos, { matchId, playerKey: intruder, now: T0 })).rejects.toMatchObject({ code: "NOT_FOUND" });
      await expect(answerQuestion(repos, { matchId, playerKey: intruder, questionIndex: 0, selectedIndex: 0, now: T0 })).rejects.toMatchObject({ status: 404 });
      await expect(getResults(repos, { matchId, playerKey: intruder })).rejects.toBeInstanceOf(GameServiceError);
    });

    it("does not reveal results before completion", async () => {
      const repos = await makeRepos();
      const playerKey = player();
      const { matchId } = await startQuickPlay(repos, { playerKey, locale: "en", category: "science", now: T0 });
      await expect(getResults(repos, { matchId, playerKey })).rejects.toMatchObject({ code: "NOT_COMPLETED" });
    });

    it("handles duplicate and simultaneous submissions exactly once", async () => {
      const repos = await makeRepos();
      const playerKey = player();
      const { matchId } = await startQuickPlay(repos, { playerKey, locale: "it", category: "mixed", now: T0 });
      const sel = await correctIndexOf(repos, matchId);
      const results = await Promise.all(
        Array.from({ length: 5 }, () => answerQuestion(repos, { matchId, playerKey, questionIndex: 0, selectedIndex: sel, now: T0 + 1_000 })),
      );
      const scored = results.filter((r) => !r.feedback.duplicate);
      expect(scored).toHaveLength(1);
      expect(new Set(results.map((r) => r.feedback.points)).size).toBe(1);
      const state = (await repos.matches.get(matchId))!;
      expect(state.answers).toHaveLength(1);
      expect(state.score).toBe(results[0].feedback.points);
    });

    it("keeps the original timer when the question is re-fetched (reconnect)", async () => {
      const repos = await makeRepos();
      const playerKey = player();
      const { matchId } = await startQuickPlay(repos, { playerKey, locale: "it", category: "mixed", now: T0 });
      const again = await getCurrentQuestion(repos, { matchId, playerKey, now: T0 + 5_000 });
      expect(again.question?.remainingMs).toBe(7_000);
    });

    it("rejects out-of-order answers", async () => {
      const repos = await makeRepos();
      const playerKey = player();
      const { matchId } = await startQuickPlay(repos, { playerKey, locale: "it", category: "mixed", now: T0 });
      await expect(answerQuestion(repos, { matchId, playerKey, questionIndex: 4, selectedIndex: 0, now: T0 })).rejects.toMatchObject({ code: "OUT_OF_ORDER" });
    });

    it("avoids repeating questions across consecutive matches for the same player", async () => {
      const repos = await makeRepos();
      const playerKey = player();
      const ids = async (seed: number) => {
        const { matchId } = await startQuickPlay(repos, { playerKey, locale: "it", category: "mixed", now: T0 + seed, rng: createRng(seed) });
        return (await repos.matches.get(matchId))!.questions.map((q) => q.questionId);
      };
      const a = await ids(1);
      const b = await ids(2);
      expect(a.filter((id) => b.includes(id))).toHaveLength(0);
    });

    it("lists every seeded category as playable", async () => {
      const repos = await makeRepos();
      expect(await availableCategories(repos, "it")).toEqual([...QUESTION_CATEGORIES]);
    });
  });
}

gameplaySuite("memory", () => createMemoryRepositories());
