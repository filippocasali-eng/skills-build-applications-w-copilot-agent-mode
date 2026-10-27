import { describe, expect, it } from "vitest";
import {
  canTransition,
  createSoloMatch,
  deliverCurrentQuestion,
  expireIfStale,
  MATCH_TRANSITIONS,
  MATCH_TTL_MS,
  MatchError,
  submitAnswer,
  toPublicQuestion,
  transition,
} from "@/features/gameplay/engine";
import { loadSeedQuestions } from "@/features/questions/bank";
import { buildMatchQuestions, selectQuestions } from "@/features/questions/selection";
import { createRng } from "@/lib/random";
import type { MatchState } from "@/types/game";

const pool = loadSeedQuestions().filter((q) => q.locale === "it");
const T0 = 1_000_000;

function newMatch(seed = "m"): { state: MatchState; picked: ReturnType<typeof selectQuestions> } {
  const rng = createRng(seed);
  const picked = selectQuestions({ pool, category: "mixed", rng });
  const state = createSoloMatch({
    id: "00000000-0000-4000-8000-000000000001",
    mode: "quick_play",
    playerKey: "guest:test",
    locale: "it",
    category: "mixed",
    rulesetVersion: "v1",
    questions: buildMatchQuestions(picked, rng),
    now: T0,
  });
  return { state, picked };
}

const correct = (s: MatchState) => s.questions[s.currentIndex].correctDisplayIndex;
const wrong = (s: MatchState) => (correct(s) + 1) % 4;

describe("state machine transitions", () => {
  it("allows only documented transitions", () => {
    expect(canTransition("CREATED", "ACTIVE")).toBe(true);
    expect(canTransition("ACTIVE", "COMPLETED")).toBe(true);
    expect(canTransition("COMPLETED", "ACTIVE")).toBe(false);
    for (const terminal of ["COMPLETED", "CANCELLED", "EXPIRED"] as const) {
      expect(MATCH_TRANSITIONS[terminal]).toHaveLength(0);
    }
  });

  it("throws on an invalid transition", () => {
    const { state } = newMatch();
    const done = transition(state, "CANCELLED", T0);
    expect(() => transition(done, "ACTIVE", T0)).toThrow(MatchError);
  });

  it("creates solo matches directly in ACTIVE", () => {
    const { state } = newMatch();
    expect(state.status).toBe("ACTIVE");
    expect(state.currentIndex).toBe(0);
    expect(state.version).toBe(0);
  });
});

describe("question delivery", () => {
  it("starts the timer on first delivery and never resets it", () => {
    const { state } = newMatch();
    const d1 = deliverCurrentQuestion(state, T0 + 100);
    expect(d1.currentIssuedAt).toBe(T0 + 100);
    const d2 = deliverCurrentQuestion(d1, T0 + 5_000);
    expect(d2).toBe(d1);
  });

  it("never exposes the correct answer in the public view", () => {
    const { state, picked } = newMatch();
    const d = deliverCurrentQuestion(state, T0);
    const pub = toPublicQuestion(d, picked[0], T0 + 2_000);
    expect(pub).not.toHaveProperty("correctIndex");
    expect(pub).not.toHaveProperty("correctDisplayIndex");
    expect(JSON.stringify(pub)).not.toContain(picked[0].explanation);
    expect(pub.remainingMs).toBe(10_000);
    expect(pub.options).toHaveLength(4);
    expect(pub.options[d.questions[0].correctDisplayIndex]).toBe(picked[0].options[picked[0].correctIndex]);
  });

  it("rejects mismatched question data", () => {
    const { state, picked } = newMatch();
    expect(() => toPublicQuestion(state, picked[1], T0)).toThrow();
  });
});

describe("submitAnswer", () => {
  it("scores a correct answer using server-measured time", () => {
    const { state } = newMatch();
    const d = deliverCurrentQuestion(state, T0);
    const r = submitAnswer(d, { questionIndex: 0, selectedIndex: correct(d), now: T0 + 3_000 });
    expect(r.feedback.correct).toBe(true);
    expect(r.feedback.points).toBe(175); // easy: 100 + 75 speed bonus
    expect(r.state.score).toBe(175);
    expect(r.state.streak).toBe(1);
    expect(r.state.currentIndex).toBe(1);
    expect(r.state.currentIssuedAt).toBeNull();
  });

  it("scores a wrong answer as zero and reveals the correct index", () => {
    const { state } = newMatch();
    const d = deliverCurrentQuestion(state, T0);
    const r = submitAnswer(d, { questionIndex: 0, selectedIndex: wrong(d), now: T0 + 1_000 });
    expect(r.feedback.correct).toBe(false);
    expect(r.feedback.points).toBe(0);
    expect(r.feedback.correctIndex).toBe(correct(d));
  });

  it("treats null as a timeout", () => {
    const { state } = newMatch();
    const d = deliverCurrentQuestion(state, T0);
    const r = submitAnswer(d, { questionIndex: 0, selectedIndex: null, now: T0 + 12_000 });
    expect(r.feedback.timedOut).toBe(true);
    expect(r.feedback.points).toBe(0);
  });

  it("converts a correct but late answer into a timeout", () => {
    const { state } = newMatch();
    const d = deliverCurrentQuestion(state, T0);
    const r = submitAnswer(d, { questionIndex: 0, selectedIndex: correct(d), now: T0 + 13_500 });
    expect(r.feedback.timedOut).toBe(true);
    expect(r.feedback.correct).toBe(false);
    expect(r.state.answers[0].selectedIndex).toBeNull();
  });

  it("accepts a correct answer inside the latency grace with zero speed bonus", () => {
    const { state } = newMatch();
    const d = deliverCurrentQuestion(state, T0);
    const r = submitAnswer(d, { questionIndex: 0, selectedIndex: correct(d), now: T0 + 12_800 });
    expect(r.feedback.correct).toBe(true);
    expect(r.feedback.speedBonus).toBe(0);
  });

  it("is idempotent for duplicate submissions", () => {
    const { state } = newMatch();
    const d = deliverCurrentQuestion(state, T0);
    const first = submitAnswer(d, { questionIndex: 0, selectedIndex: correct(d), now: T0 + 1_000 });
    const again = submitAnswer(first.state, { questionIndex: 0, selectedIndex: wrong(d), now: T0 + 2_000 });
    expect(again.duplicate).toBe(true);
    expect(again.state).toBe(first.state);
    expect(again.feedback.correct).toBe(true);
    expect(again.feedback.points).toBe(first.feedback.points);
  });

  it("rejects answers for future questions", () => {
    const { state } = newMatch();
    const d = deliverCurrentQuestion(state, T0);
    expect(() => submitAnswer(d, { questionIndex: 3, selectedIndex: 0, now: T0 })).toThrow(/current question/);
  });

  it("rejects answers before the question was delivered", () => {
    const { state } = newMatch();
    expect(() => submitAnswer(state, { questionIndex: 0, selectedIndex: 0, now: T0 })).toThrow(/not delivered/);
  });

  it("rejects out-of-range answer indexes", () => {
    const { state } = newMatch();
    const d = deliverCurrentQuestion(state, T0);
    for (const bad of [-1, 4, 1.5]) {
      expect(() => submitAnswer(d, { questionIndex: 0, selectedIndex: bad, now: T0 })).toThrow(MatchError);
    }
  });

  it("builds streak multipliers across consecutive correct answers and resets on a miss", () => {
    let { state } = newMatch();
    const points: number[] = [];
    for (let i = 0; i < 6; i++) {
      state = deliverCurrentQuestion(state, T0 + i * 20_000);
      const sel = i === 5 ? wrong(state) : correct(state);
      const r = submitAnswer(state, { questionIndex: i, selectedIndex: sel, now: T0 + i * 20_000 + 12_000 });
      points.push(r.feedback.points);
      state = r.state;
    }
    // Answers at exactly 12 s get no speed bonus: base * multiplier.
    expect(points).toEqual([100, 110, 120, 195, 225, 0]);
    expect(state.streak).toBe(0);
    expect(state.bestStreak).toBe(5);
  });

  it("completes after the last question and refuses further play (no replay)", () => {
    let { state } = newMatch();
    for (let i = 0; i < 10; i++) {
      state = deliverCurrentQuestion(state, T0 + i * 1000);
      state = submitAnswer(state, { questionIndex: i, selectedIndex: correct(state), now: T0 + i * 1000 + 500 }).state;
    }
    expect(state.status).toBe("COMPLETED");
    expect(state.completedAt).toBe(T0 + 9_500);
    expect(state.answers).toHaveLength(10);
    expect(() => deliverCurrentQuestion(state, T0 + 20_000)).toThrow(/not active/);
    expect(() => submitAnswer(state, { questionIndex: 10, selectedIndex: 0, now: T0 + 20_000 })).toThrow(/not active/);
    // Re-sending an earlier answer still returns the stored result without changes.
    expect(submitAnswer(state, { questionIndex: 9, selectedIndex: 0, now: T0 + 20_000 }).duplicate).toBe(true);
  });
});

describe("expiry", () => {
  it("expires an abandoned active match", () => {
    const { state } = newMatch();
    const d = deliverCurrentQuestion(state, T0);
    expect(expireIfStale(d, T0 + 1_000)).toBe(d);
    const expired = expireIfStale(d, T0 + MATCH_TTL_MS + 1);
    expect(expired.status).toBe("EXPIRED");
    expect(() => submitAnswer(d, { questionIndex: 0, selectedIndex: 0, now: T0 + MATCH_TTL_MS + 1 })).toThrow(/expired/i);
  });
});
