/**
 * Core domain types shared by the server-side game engine and the client.
 * Nothing in this file may reference React, Next.js or a database driver.
 */

export const LOCALES = ["it", "en"] as const;
export type Locale = (typeof LOCALES)[number];
export const DEFAULT_LOCALE: Locale = "it";

export const DIFFICULTIES = ["easy", "medium", "hard", "expert"] as const;
export type Difficulty = (typeof DIFFICULTIES)[number];

/** Playable categories. "mixed" is a selection mode, not a stored question category. */
export const QUESTION_CATEGORIES = [
  "general",
  "history",
  "geography",
  "science",
  "technology",
  "movies_tv",
  "music",
  "sports",
  "nature",
  "food",
  "art",
  "logic",
  "video_games",
  "pop_culture",
] as const;
export type QuestionCategory = (typeof QUESTION_CATEGORIES)[number];
export type CategorySelection = QuestionCategory | "mixed";

export const REVIEW_STATUSES = ["draft", "pending_review", "approved", "rejected"] as const;
export type ReviewStatus = (typeof REVIEW_STATUSES)[number];

export interface QuestionSource {
  /** How the question was produced. */
  kind: "editorial" | "seed_ai_assisted" | "ai_generated";
  /** Human-readable reference used for fact checking (e.g. an encyclopedia article). */
  reference: string;
}

/** A single-language question as stored in the bank. Contains the answer: server-only. */
export interface Question {
  id: string;
  /** Groups translations of the same question across locales. */
  translationKey: string;
  locale: Locale;
  category: QuestionCategory;
  difficulty: Difficulty;
  text: string;
  options: [string, string, string, string];
  correctIndex: 0 | 1 | 2 | 3;
  explanation: string;
  source: QuestionSource;
  reviewStatus: ReviewStatus;
  /** Only questions explicitly cleared by a human reviewer may be used in ranked modes. */
  rankedEligible: boolean;
  version: number;
  createdAt: string;
}

export const MATCH_STATUSES = [
  "CREATED",
  "WAITING",
  "READY",
  "ACTIVE",
  "COMPLETED",
  "CANCELLED",
  "EXPIRED",
] as const;
export type MatchStatus = (typeof MATCH_STATUSES)[number];

export type GameMode = "quick_play";

/** A question slot inside a match, with the answer order fixed at creation time. */
export interface MatchQuestion {
  questionId: string;
  category: QuestionCategory;
  difficulty: Difficulty;
  /** optionOrder[displayIndex] = canonical option index in the stored question. */
  optionOrder: [number, number, number, number];
  /** Display index of the correct option. Server-only. */
  correctDisplayIndex: number;
}

export interface AnswerRecord {
  questionIndex: number;
  /** Display index chosen by the player, or null when the timer expired. */
  selectedIndex: number | null;
  correct: boolean;
  timedOut: boolean;
  /** Server-measured time between question delivery and answer receipt. */
  elapsedMs: number;
  points: number;
  basePoints: number;
  speedBonus: number;
  multiplier: number;
  streakAfter: number;
  answeredAt: number;
}

export interface MatchState {
  id: string;
  mode: GameMode;
  status: MatchStatus;
  /** Opaque player key, e.g. "guest:<uuid>" or "user:<uuid>". */
  playerKey: string;
  locale: Locale;
  category: CategorySelection;
  rulesetVersion: string;
  questions: MatchQuestion[];
  currentIndex: number;
  /** Server timestamp (ms) at which the current question was first delivered. */
  currentIssuedAt: number | null;
  answers: AnswerRecord[];
  score: number;
  streak: number;
  bestStreak: number;
  createdAt: number;
  completedAt: number | null;
  /** Optimistic-concurrency counter, incremented on every persisted transition. */
  version: number;
}

/** What the client is allowed to see about a question: no correct answer. */
export interface PublicQuestion {
  index: number;
  total: number;
  category: QuestionCategory;
  difficulty: Difficulty;
  text: string;
  options: string[];
  timeLimitMs: number;
  /** Remaining time computed by the server at delivery. */
  remainingMs: number;
}

export interface AnswerFeedback {
  questionIndex: number;
  correct: boolean;
  timedOut: boolean;
  selectedIndex: number | null;
  correctIndex: number;
  points: number;
  speedBonus: number;
  multiplier: number;
  score: number;
  streak: number;
  duplicate: boolean;
}

export interface MatchReviewItem {
  index: number;
  category: QuestionCategory;
  difficulty: Difficulty;
  text: string;
  options: string[];
  correctIndex: number;
  selectedIndex: number | null;
  correct: boolean;
  timedOut: boolean;
  points: number;
  explanation: string;
}

export interface MatchResults {
  matchId: string;
  status: MatchStatus;
  score: number;
  correctCount: number;
  totalQuestions: number;
  accuracy: number;
  bestStreak: number;
  averageResponseMs: number;
  xpEarned: number;
  rulesetVersion: string;
  review: MatchReviewItem[];
}
