import { describe, expect, it } from "vitest";
import { levelFromXp, matchXp, xpForLevel } from "@/features/progression/levels";

describe("level curve", () => {
  it("matches the documented thresholds", () => {
    expect([1, 2, 3, 4, 5].map((l) => xpForLevel(l))).toEqual([0, 100, 250, 450, 700]);
  });

  it("derives level and progress from XP", () => {
    expect(levelFromXp(0)).toEqual({ level: 1, xpIntoLevel: 0, xpForNext: 100, progress: 0 });
    expect(levelFromXp(99).level).toBe(1);
    expect(levelFromXp(100).level).toBe(2);
    expect(levelFromXp(300)).toEqual({ level: 3, xpIntoLevel: 50, xpForNext: 200, progress: 0.25 });
  });

  it("caps at the max level", () => {
    const r = levelFromXp(10_000_000);
    expect(r.level).toBe(100);
    expect(r.progress).toBe(1);
  });

  it("treats negative XP as zero", () => {
    expect(levelFromXp(-50).level).toBe(1);
  });
});

describe("matchXp", () => {
  it("rewards completion, correct answers and a perfect match", () => {
    expect(matchXp(0, 10, true)).toBe(20);
    expect(matchXp(7, 10, true)).toBe(90);
    expect(matchXp(10, 10, true)).toBe(170);
  });
  it("gives nothing for an abandoned match", () => {
    expect(matchXp(5, 10, false)).toBe(0);
  });
});
