import { describe, expect, it } from "vitest";
import { ACHIEVEMENTS, achievementProgress } from "@/features/achievements/catalog";
import { applyMatch, EMPTY_PROGRESS, localDay, type PlayerProgress } from "@/features/progression/player";
import type { MatchResults, MatchReviewItem } from "@/types/game";

const DAY = new Date(2026, 9, 28, 15).getTime();

function results(over: Partial<MatchResults> & { correct?: number; fast?: number } = {}): MatchResults {
  const correct = over.correct ?? 7;
  const fast = over.fast ?? 0;
  const review: MatchReviewItem[] = Array.from({ length: 10 }, (_, i) => ({
    index: i, category: i < 5 ? "geography" : "science", difficulty: "easy", text: "q", options: ["a", "b", "c", "d"],
    correctIndex: 0, selectedIndex: i < correct ? 0 : 1, correct: i < correct, timedOut: false, points: i < correct ? 150 : 0,
    elapsedMs: i < fast ? 1_000 : 5_000, explanation: "e",
  }));
  return {
    matchId: crypto.randomUUID(), mode: "quick_play", category: "mixed", challengeDate: null, status: "COMPLETED",
    score: correct * 150, correctCount: correct, totalQuestions: 10, accuracy: correct / 10, bestStreak: correct,
    averageResponseMs: 4_000, xpEarned: 20 + correct * 10 + (correct === 10 ? 50 : 0), rulesetVersion: "v1", review, ...over,
  };
}

describe("applyMatch", () => {
  it("accumulates stats, history, category accuracy and XP", () => {
    const r = results();
    const { progress, previousBest } = applyMatch(EMPTY_PROGRESS, r, DAY);
    expect(previousBest).toBe(0);
    expect(progress.matches).toBe(1);
    expect(progress.correct).toBe(7);
    expect(progress.answered).toBe(10);
    expect(progress.bestScore).toBe(1050);
    expect(progress.xp).toBe(90);
    expect(progress.categories.geography).toEqual({ correct: 5, answered: 5 });
    expect(progress.categories.science).toEqual({ correct: 2, answered: 5 });
    expect(progress.history[0]).toMatchObject({ id: r.matchId, score: 1050, correct: 7 });
    expect(progress.dayStreak).toBe(1);
  });

  it("credits each match only once", () => {
    const r = results();
    const once = applyMatch(EMPTY_PROGRESS, r, DAY).progress;
    const twice = applyMatch(once, r, DAY);
    expect(twice.alreadyCredited).toBe(true);
    expect(twice.progress).toBe(once);
  });

  it("tracks consecutive-day streaks in local time", () => {
    let p: PlayerProgress = EMPTY_PROGRESS;
    p = applyMatch(p, results(), DAY).progress;
    p = applyMatch(p, results(), DAY + 3_600_000).progress;
    expect(p.dayStreak).toBe(1);
    p = applyMatch(p, results(), DAY + 86_400_000).progress;
    expect(p.dayStreak).toBe(2);
    p = applyMatch(p, results(), DAY + 4 * 86_400_000).progress;
    expect(p.dayStreak).toBe(1);
    expect(p.bestDayStreak).toBe(2);
    expect(localDay(DAY)).toBe("2026-10-28");
  });

  it("unlocks achievements once, grants their XP and reports level-ups", () => {
    const first = applyMatch(EMPTY_PROGRESS, results({ correct: 10, fast: 6 }), DAY);
    const ids = first.unlocked.map((a) => a.id);
    expect(ids).toEqual(expect.arrayContaining(["perfect_match", "speed_demon"]));
    expect(ids).not.toContain("first_victory");
    // 170 match XP + 50 (perfect) + 50 (speed demon)
    expect(first.progress.xp).toBe(270);
    expect(first.levelBefore).toBe(1);
    expect(first.levelAfter).toBe(3);
    const second = applyMatch(first.progress, results({ correct: 10, fast: 6 }), DAY);
    expect(second.unlocked.map((a) => a.id)).not.toContain("perfect_match");
  });

  it("records the daily challenge once per day", () => {
    const r = results({ mode: "daily_challenge", challengeDate: "2026-10-28" });
    const { progress, unlocked } = applyMatch(EMPTY_PROGRESS, r, DAY);
    expect(progress.daily["2026-10-28"]).toEqual({ score: 1050, correct: 7, total: 10 });
    expect(unlocked.map((a) => a.id)).toContain("daily_challenger");
    const again = applyMatch(progress, results({ mode: "daily_challenge", challengeDate: "2026-10-28", correct: 10 }), DAY).progress;
    expect(again.daily["2026-10-28"].correct).toBe(7);
  });

  it("caps achievement progress at 100% and keeps multiplayer ones locked", () => {
    const p = applyMatch(EMPTY_PROGRESS, results(), DAY).progress;
    const matches10 = ACHIEVEMENTS.find((a) => a.id === "matches_10")!;
    expect(achievementProgress(matches10, p)).toBeCloseTo(0.1);
    const geo = ACHIEVEMENTS.find((a) => a.id === "geography_expert")!;
    expect(achievementProgress(geo, { ...p, categories: { geography: { correct: 80, answered: 90 } } })).toBe(1);
    expect(ACHIEVEMENTS.filter((a) => a.multiplayer).every((a) => !p.achievements[a.id])).toBe(true);
  });
});
