import { describe, expect, it } from "vitest";
import {
  CURRENT_RULESET,
  getRuleset,
  isLate,
  scoreAnswer,
  speedBonus,
  streakMultiplier,
  summarizeAnswers,
  SCORING_RULESET_V1,
} from "@/lib/scoring";
import type { AnswerRecord } from "@/types/game";

describe("streakMultiplier", () => {
  it.each([
    [0, 1],
    [1, 1.0],
    [2, 1.1],
    [3, 1.2],
    [4, 1.3],
    [5, 1.5],
    [9, 1.5],
  ])("streak %i -> %f", (streak, expected) => {
    expect(streakMultiplier(streak)).toBe(expected);
  });
});

describe("speedBonus", () => {
  it("is 100 for an instant answer and 0 at the limit", () => {
    expect(speedBonus(0)).toBe(100);
    expect(speedBonus(12_000)).toBe(0);
    expect(speedBonus(20_000)).toBe(0);
  });
  it("is linear in remaining time", () => {
    expect(speedBonus(6_000)).toBe(50);
    expect(speedBonus(3_000)).toBe(75);
  });
  it("clamps negative elapsed time (clock skew) to the maximum", () => {
    expect(speedBonus(-500)).toBe(100);
  });
});

describe("scoreAnswer", () => {
  it("scores a correct easy answer with base + speed bonus", () => {
    const r = scoreAnswer({ difficulty: "easy", correct: true, timedOut: false, elapsedMs: 6_000, previousStreak: 0 });
    expect(r).toEqual({ points: 150, basePoints: 100, speedBonus: 50, multiplier: 1, streakAfter: 1 });
  });

  it("uses difficulty base points", () => {
    const at = (d: "easy" | "medium" | "hard" | "expert") =>
      scoreAnswer({ difficulty: d, correct: true, timedOut: false, elapsedMs: 12_000, previousStreak: 0 }).points;
    expect([at("easy"), at("medium"), at("hard"), at("expert")]).toEqual([100, 150, 200, 250]);
  });

  it("applies the streak multiplier to base + bonus", () => {
    const r = scoreAnswer({ difficulty: "hard", correct: true, timedOut: false, elapsedMs: 0, previousStreak: 4 });
    expect(r.multiplier).toBe(1.5);
    expect(r.points).toBe(Math.round((200 + 100) * 1.5));
    expect(r.streakAfter).toBe(5);
  });

  it("gives zero points and resets the streak on a wrong answer", () => {
    const r = scoreAnswer({ difficulty: "expert", correct: false, timedOut: false, elapsedMs: 100, previousStreak: 7 });
    expect(r).toEqual({ points: 0, basePoints: 0, speedBonus: 0, multiplier: 1, streakAfter: 0 });
  });

  it("gives zero points and resets the streak on timeout even if 'correct' was passed", () => {
    const r = scoreAnswer({ difficulty: "easy", correct: true, timedOut: true, elapsedMs: 12_500, previousStreak: 3 });
    expect(r.points).toBe(0);
    expect(r.streakAfter).toBe(0);
  });

  it("is deterministic", () => {
    const input = { difficulty: "medium" as const, correct: true, timedOut: false, elapsedMs: 4321, previousStreak: 2 };
    expect(scoreAnswer(input)).toEqual(scoreAnswer(input));
  });
});

describe("rulesets", () => {
  it("resolves known versions and rejects unknown ones", () => {
    expect(getRuleset("v1")).toBe(SCORING_RULESET_V1);
    expect(CURRENT_RULESET.version).toBe("v1");
    expect(() => getRuleset("v999")).toThrow(/Unknown scoring ruleset/);
  });
  it("published rulesets are immutable", () => {
    expect(Object.isFrozen(SCORING_RULESET_V1)).toBe(true);
    expect(Object.isFrozen(SCORING_RULESET_V1.basePoints)).toBe(true);
  });
  it("treats answers beyond limit + grace as late", () => {
    expect(isLate(12_000)).toBe(false);
    expect(isLate(13_000)).toBe(false);
    expect(isLate(13_001)).toBe(true);
  });
});

describe("summarizeAnswers", () => {
  const rec = (p: Partial<AnswerRecord>): AnswerRecord => ({
    questionIndex: 0, selectedIndex: 0, correct: true, timedOut: false, elapsedMs: 1000, points: 100,
    basePoints: 100, speedBonus: 0, multiplier: 1, streakAfter: 1, answeredAt: 0, ...p,
  });

  it("computes the final score, accuracy and best streak", () => {
    const s = summarizeAnswers(
      [rec({ points: 150, streakAfter: 1 }), rec({ points: 200, streakAfter: 2, elapsedMs: 3000 }), rec({ correct: false, points: 0, streakAfter: 0 })],
      10,
    );
    expect(s).toEqual({ score: 350, correctCount: 2, answered: 3, accuracy: 0.2, bestStreak: 2, averageResponseMs: 1667 });
  });

  it("handles an empty match", () => {
    expect(summarizeAnswers([], 0)).toEqual({ score: 0, correctCount: 0, answered: 0, accuracy: 0, bestStreak: 0, averageResponseMs: 0 });
  });
});
