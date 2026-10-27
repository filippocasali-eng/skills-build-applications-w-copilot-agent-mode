import type { AnswerRecord, Difficulty } from "@/types/game";

/**
 * Deterministic scoring rules. Every match persists the `version` it was scored
 * with; never mutate a published ruleset — add a new version instead.
 */
export interface ScoringRuleset {
  version: string;
  timeLimitMs: number;
  /** Extra time tolerated for network latency before an answer counts as late. */
  latencyGraceMs: number;
  basePoints: Record<Difficulty, number>;
  maxSpeedBonus: number;
  /** streakMultipliers[n-1] applies to the n-th consecutive correct answer; the last value applies beyond. */
  streakMultipliers: readonly number[];
}

export const SCORING_RULESET_V1: ScoringRuleset = Object.freeze({
  version: "v1",
  timeLimitMs: 12_000,
  latencyGraceMs: 1_000,
  basePoints: Object.freeze({ easy: 100, medium: 150, hard: 200, expert: 250 }),
  maxSpeedBonus: 100,
  streakMultipliers: Object.freeze([1.0, 1.1, 1.2, 1.3, 1.5]),
});

const RULESETS: Record<string, ScoringRuleset> = { [SCORING_RULESET_V1.version]: SCORING_RULESET_V1 };

export const CURRENT_RULESET = SCORING_RULESET_V1;

export function getRuleset(version: string): ScoringRuleset {
  const ruleset = RULESETS[version];
  if (!ruleset) throw new Error(`Unknown scoring ruleset: ${version}`);
  return ruleset;
}

/** Multiplier for a streak length that already includes the current correct answer. */
export function streakMultiplier(streak: number, rules: ScoringRuleset = CURRENT_RULESET): number {
  if (streak <= 0) return 1;
  const table = rules.streakMultipliers;
  return table[Math.min(streak, table.length) - 1];
}

/** Speed bonus from remaining time: linear from maxSpeedBonus (instant) to 0 (at the limit). */
export function speedBonus(elapsedMs: number, rules: ScoringRuleset = CURRENT_RULESET): number {
  const elapsed = Math.max(0, elapsedMs);
  const remaining = Math.max(0, rules.timeLimitMs - elapsed);
  return Math.round((rules.maxSpeedBonus * remaining) / rules.timeLimitMs);
}

export interface ScoreInput {
  difficulty: Difficulty;
  correct: boolean;
  timedOut: boolean;
  elapsedMs: number;
  /** Consecutive correct answers before this one. */
  previousStreak: number;
}

export interface ScoreOutcome {
  points: number;
  basePoints: number;
  speedBonus: number;
  multiplier: number;
  streakAfter: number;
}

/**
 * points = round((basePoints[difficulty] + speedBonus) * streakMultiplier(previousStreak + 1))
 * Wrong or timed-out answers score 0 and reset the streak.
 */
export function scoreAnswer(input: ScoreInput, rules: ScoringRuleset = CURRENT_RULESET): ScoreOutcome {
  if (!input.correct || input.timedOut) {
    return { points: 0, basePoints: 0, speedBonus: 0, multiplier: 1, streakAfter: 0 };
  }
  const streakAfter = Math.max(0, input.previousStreak) + 1;
  const base = rules.basePoints[input.difficulty];
  const bonus = speedBonus(input.elapsedMs, rules);
  const multiplier = streakMultiplier(streakAfter, rules);
  return {
    points: Math.round((base + bonus) * multiplier),
    basePoints: base,
    speedBonus: bonus,
    multiplier,
    streakAfter,
  };
}

/** True when an answer arrived too late to count (limit + latency grace). */
export function isLate(elapsedMs: number, rules: ScoringRuleset = CURRENT_RULESET): boolean {
  return elapsedMs > rules.timeLimitMs + rules.latencyGraceMs;
}

export interface MatchSummary {
  score: number;
  correctCount: number;
  answered: number;
  accuracy: number;
  bestStreak: number;
  averageResponseMs: number;
}

export function summarizeAnswers(answers: readonly AnswerRecord[], totalQuestions: number): MatchSummary {
  let score = 0;
  let correctCount = 0;
  let bestStreak = 0;
  let totalMs = 0;
  for (const a of answers) {
    score += a.points;
    if (a.correct) correctCount++;
    bestStreak = Math.max(bestStreak, a.streakAfter);
    totalMs += a.elapsedMs;
  }
  return {
    score,
    correctCount,
    answered: answers.length,
    accuracy: totalQuestions > 0 ? correctCount / totalQuestions : 0,
    bestStreak,
    averageResponseMs: answers.length > 0 ? Math.round(totalMs / answers.length) : 0,
  };
}
