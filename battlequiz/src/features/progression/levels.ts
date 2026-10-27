/**
 * Level curve: the XP needed to go from level n to n+1 is
 * `baseStep + (n - 1) * stepIncrement`. With the defaults this yields
 * L1 = 0, L2 = 100, L3 = 250, L4 = 450, L5 = 700, ...
 */
export interface LevelCurve {
  baseStep: number;
  stepIncrement: number;
  maxLevel: number;
}

export const DEFAULT_LEVEL_CURVE: LevelCurve = { baseStep: 100, stepIncrement: 50, maxLevel: 100 };

/** Total XP required to reach `level`. */
export function xpForLevel(level: number, curve: LevelCurve = DEFAULT_LEVEL_CURVE): number {
  const n = Math.max(1, Math.min(Math.floor(level), curve.maxLevel)) - 1;
  // Sum of an arithmetic series of n steps.
  return n * curve.baseStep + (curve.stepIncrement * n * (n - 1)) / 2;
}

export interface LevelProgress {
  level: number;
  xpIntoLevel: number;
  xpForNext: number;
  /** 0..1 progress toward the next level (1 at max level). */
  progress: number;
}

export function levelFromXp(totalXp: number, curve: LevelCurve = DEFAULT_LEVEL_CURVE): LevelProgress {
  const xp = Math.max(0, Math.floor(totalXp));
  let level = 1;
  while (level < curve.maxLevel && xp >= xpForLevel(level + 1, curve)) level++;
  if (level === curve.maxLevel) return { level, xpIntoLevel: 0, xpForNext: 0, progress: 1 };
  const floor = xpForLevel(level, curve);
  const next = xpForLevel(level + 1, curve);
  return { level, xpIntoLevel: xp - floor, xpForNext: next - floor, progress: (xp - floor) / (next - floor) };
}

export interface XpRules {
  completion: number;
  perCorrect: number;
  perfectBonus: number;
}

export const DEFAULT_XP_RULES: XpRules = { completion: 20, perCorrect: 10, perfectBonus: 50 };

/** XP for a completed match. Abandoned or expired matches earn nothing. */
export function matchXp(
  correctCount: number,
  totalQuestions: number,
  completed: boolean,
  rules: XpRules = DEFAULT_XP_RULES,
): number {
  if (!completed) return 0;
  const perfect = totalQuestions > 0 && correctCount === totalQuestions;
  return rules.completion + correctCount * rules.perCorrect + (perfect ? rules.perfectBonus : 0);
}
