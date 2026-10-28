import { newlyUnlocked, type AchievementDef } from "@/features/achievements/catalog";
import type { CategorySelection, GameMode, MatchResults, QuestionCategory } from "@/types/game";
import { levelFromXp } from "./levels";

/**
 * On-device player progression (guest / offline). Pure functions: the store
 * persists the result. Server-side, authoritative progression for accounts
 * arrives in Milestone 2 and will use the same rules.
 */
export const FAST_ANSWER_MS = 2_000;
const HISTORY_LIMIT = 50;

export interface MatchSummary {
  id: string;
  mode: GameMode;
  category: CategorySelection;
  score: number;
  correct: number;
  total: number;
  bestStreak: number;
  xp: number;
  at: number;
}

export interface PlayerProgress {
  xp: number;
  matches: number;
  correct: number;
  answered: number;
  totalResponseMs: number;
  bestScore: number;
  bestStreak: number;
  perfectMatches: number;
  bestFastAnswers: number;
  dailyCompleted: number;
  wins: number;
  bestWinStreak: number;
  categories: Partial<Record<QuestionCategory, { correct: number; answered: number }>>;
  dayStreak: number;
  bestDayStreak: number;
  lastPlayedDay: string | null;
  history: MatchSummary[];
  achievements: Record<string, number>;
  /** Daily challenge results by UTC day. */
  daily: Record<string, { score: number; correct: number; total: number }>;
  credited: string[];
}

export const EMPTY_PROGRESS: PlayerProgress = {
  xp: 0,
  matches: 0,
  correct: 0,
  answered: 0,
  totalResponseMs: 0,
  bestScore: 0,
  bestStreak: 0,
  perfectMatches: 0,
  bestFastAnswers: 0,
  dailyCompleted: 0,
  wins: 0,
  bestWinStreak: 0,
  categories: {},
  dayStreak: 0,
  bestDayStreak: 0,
  lastPlayedDay: null,
  history: [],
  achievements: {},
  daily: {},
  credited: [],
};

/** Local calendar day (YYYY-MM-DD) for streaks: players think in their own days. */
export function localDay(now: number): string {
  const d = new Date(now);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function previousDay(day: string): string {
  const [y, m, d] = day.split("-").map(Number);
  return localDay(new Date(y, m - 1, d - 1, 12).getTime());
}

export interface ApplyResult {
  progress: PlayerProgress;
  unlocked: AchievementDef[];
  levelBefore: number;
  levelAfter: number;
  previousBest: number;
  alreadyCredited: boolean;
}

/** Credits a completed match exactly once (by match id). */
export function applyMatch(p: PlayerProgress, r: MatchResults, now: number): ApplyResult {
  const levelBefore = levelFromXp(p.xp).level;
  if (p.credited.includes(r.matchId)) {
    return { progress: p, unlocked: [], levelBefore, levelAfter: levelBefore, previousBest: p.bestScore, alreadyCredited: true };
  }

  const categories = { ...p.categories };
  for (const item of r.review) {
    const c = categories[item.category] ?? { correct: 0, answered: 0 };
    categories[item.category] = { correct: c.correct + (item.correct ? 1 : 0), answered: c.answered + 1 };
  }

  const today = localDay(now);
  const dayStreak = p.lastPlayedDay === today ? p.dayStreak : p.lastPlayedDay === previousDay(today) ? p.dayStreak + 1 : 1;
  const fast = r.review.filter((i) => i.correct && i.elapsedMs < FAST_ANSWER_MS).length;
  const perfect = r.correctCount === r.totalQuestions;
  const daily = r.mode === "daily_challenge" && r.challengeDate;

  let next: PlayerProgress = {
    ...p,
    xp: p.xp + r.xpEarned,
    matches: p.matches + 1,
    correct: p.correct + r.correctCount,
    answered: p.answered + r.totalQuestions,
    totalResponseMs: p.totalResponseMs + r.averageResponseMs * r.totalQuestions,
    bestScore: Math.max(p.bestScore, r.score),
    bestStreak: Math.max(p.bestStreak, r.bestStreak),
    perfectMatches: p.perfectMatches + (perfect ? 1 : 0),
    bestFastAnswers: Math.max(p.bestFastAnswers, fast),
    dailyCompleted: p.dailyCompleted + (daily ? 1 : 0),
    categories,
    dayStreak,
    bestDayStreak: Math.max(p.bestDayStreak, dayStreak),
    lastPlayedDay: today,
    history: [
      { id: r.matchId, mode: r.mode, category: r.category, score: r.score, correct: r.correctCount, total: r.totalQuestions, bestStreak: r.bestStreak, xp: r.xpEarned, at: now },
      ...p.history,
    ].slice(0, HISTORY_LIMIT),
    daily: daily && !p.daily[r.challengeDate!] ? { ...p.daily, [r.challengeDate!]: { score: r.score, correct: r.correctCount, total: r.totalQuestions } } : p.daily,
    credited: [...p.credited, r.matchId].slice(-100),
  };

  const unlocked = newlyUnlocked(next);
  if (unlocked.length) {
    const achievements = { ...next.achievements };
    for (const a of unlocked) achievements[a.id] = now;
    next = { ...next, achievements, xp: next.xp + unlocked.reduce((s, a) => s + a.xpReward, 0) };
  }

  return { progress: next, unlocked, levelBefore, levelAfter: levelFromXp(next.xp).level, previousBest: p.bestScore, alreadyCredited: false };
}

export function averageAccuracy(p: PlayerProgress): number {
  return p.answered ? p.correct / p.answered : 0;
}
