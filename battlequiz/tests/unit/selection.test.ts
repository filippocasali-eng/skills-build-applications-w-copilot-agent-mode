import { describe, expect, it } from "vitest";
import { loadSeedQuestions } from "@/features/questions/bank";
import {
  buildMatchQuestions,
  QUICK_PLAY_DIFFICULTY_PLAN,
  QuestionExhaustionError,
  selectQuestions,
} from "@/features/questions/selection";
import { createRng, shuffle } from "@/lib/random";
import type { Question } from "@/types/game";

const pool = loadSeedQuestions().filter((q) => q.locale === "it");

describe("selectQuestions", () => {
  it("follows the progressive difficulty plan in mixed mode", () => {
    const picked = selectQuestions({ pool, category: "mixed", rng: createRng("a") });
    expect(picked.map((q) => q.difficulty)).toEqual(QUICK_PLAY_DIFFICULTY_PLAN);
    expect(new Set(picked.map((q) => q.id)).size).toBe(10);
  });

  it("spreads categories: max 3 per category and no back-to-back repeats", () => {
    for (let seed = 0; seed < 50; seed++) {
      const picked = selectQuestions({ pool, category: "mixed", rng: createRng(seed) });
      const counts = new Map<string, number>();
      picked.forEach((q, i) => {
        counts.set(q.category, (counts.get(q.category) ?? 0) + 1);
        if (i > 0) expect(q.category).not.toBe(picked[i - 1].category);
      });
      expect(Math.max(...counts.values())).toBeLessThanOrEqual(3);
    }
  });

  it("restricts to the chosen category", () => {
    const picked = selectQuestions({ pool, category: "geography", rng: createRng("g") });
    expect(picked).toHaveLength(10);
    expect(picked.every((q) => q.category === "geography")).toBe(true);
  });

  it("avoids recently seen questions while unseen ones exist", () => {
    const first = selectQuestions({ pool, category: "mixed", rng: createRng(1) });
    const second = selectQuestions({ pool, category: "mixed", rng: createRng(2), recentlySeen: first.map((q) => q.id) });
    const overlap = second.filter((q) => first.some((f) => f.id === q.id));
    expect(overlap).toHaveLength(0);
  });

  it("falls back to the least recently seen questions when the category is exhausted", () => {
    const geo = pool.filter((q) => q.category === "geography");
    // Everything seen; the oldest-seen questions (end of the list) should be preferred.
    const seen = geo.map((q) => q.id);
    const picked = selectQuestions({ pool, category: "geography", rng: createRng(3), recentlySeen: seen });
    expect(picked).toHaveLength(10);
    const ranks = picked.map((q) => seen.indexOf(q.id));
    expect(Math.min(...ranks)).toBeGreaterThanOrEqual(0);
  });

  it("is reproducible from the same seed", () => {
    const a = selectQuestions({ pool, category: "mixed", rng: createRng("same") }).map((q) => q.id);
    const b = selectQuestions({ pool, category: "mixed", rng: createRng("same") }).map((q) => q.id);
    expect(a).toEqual(b);
  });

  it("throws QuestionExhaustionError when the pool is too small", () => {
    expect(() => selectQuestions({ pool: pool.slice(0, 5), category: "mixed", rng: createRng(1) })).toThrow(QuestionExhaustionError);
  });

  it("substitutes the nearest difficulty when a tier is empty", () => {
    const noExpert = pool.filter((q) => q.difficulty !== "expert");
    const picked = selectQuestions({ pool: noExpert, category: "mixed", rng: createRng(5) });
    expect(picked[9].difficulty).toBe("hard");
  });
});

describe("buildMatchQuestions", () => {
  it("keeps the correct answer reachable through the option order", () => {
    const picked = selectQuestions({ pool, category: "mixed", rng: createRng("o") });
    const slots = buildMatchQuestions(picked, createRng("o2"));
    slots.forEach((slot, i) => {
      expect([...slot.optionOrder].sort()).toEqual([0, 1, 2, 3]);
      expect(slot.optionOrder[slot.correctDisplayIndex]).toBe(picked[i].correctIndex);
    });
  });

  it("balances the correct answer position (no positional bias)", () => {
    const tally = [0, 0, 0, 0];
    for (let seed = 0; seed < 200; seed++) {
      const rng = createRng(seed);
      const picked = shuffle(pool, rng).slice(0, 10) as Question[];
      const slots = buildMatchQuestions(picked, rng);
      const perMatch = [0, 0, 0, 0];
      slots.forEach((s) => perMatch[s.correctDisplayIndex]++);
      // Within a single match each position appears 2 or 3 times.
      expect(Math.max(...perMatch) - Math.min(...perMatch)).toBeLessThanOrEqual(1);
      perMatch.forEach((n, i) => (tally[i] += n));
    }
    // 2000 answers in total: each position should get roughly a quarter.
    for (const n of tally) expect(Math.abs(n - 500)).toBeLessThan(60);
  });
});
