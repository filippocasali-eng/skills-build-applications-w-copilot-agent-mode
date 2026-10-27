import { getRuleset, isLate, scoreAnswer } from "@/lib/scoring";
import type {
  AnswerFeedback,
  AnswerRecord,
  CategorySelection,
  GameMode,
  Locale,
  MatchQuestion,
  MatchState,
  MatchStatus,
  PublicQuestion,
  Question,
} from "@/types/game";

/**
 * Pure, server-side match state machine. Functions take a state and return a
 * new state; persistence and concurrency control live in the repository layer.
 */

/** Allowed status transitions (multiplayer statuses are reserved for later milestones). */
export const MATCH_TRANSITIONS: Readonly<Record<MatchStatus, readonly MatchStatus[]>> = {
  CREATED: ["WAITING", "ACTIVE", "CANCELLED", "EXPIRED"],
  WAITING: ["READY", "CANCELLED", "EXPIRED"],
  READY: ["ACTIVE", "CANCELLED", "EXPIRED"],
  ACTIVE: ["COMPLETED", "CANCELLED", "EXPIRED"],
  COMPLETED: [],
  CANCELLED: [],
  EXPIRED: [],
};

/** Inactive matches older than this are expired and can no longer be played. */
export const MATCH_TTL_MS = 30 * 60 * 1000;

export class MatchError extends Error {
  constructor(
    public readonly code:
      | "INVALID_TRANSITION"
      | "NOT_ACTIVE"
      | "OUT_OF_ORDER"
      | "NOT_DELIVERED"
      | "INVALID_ANSWER"
      | "EXPIRED",
    message: string,
  ) {
    super(message);
    this.name = "MatchError";
  }
}

export function canTransition(from: MatchStatus, to: MatchStatus): boolean {
  return MATCH_TRANSITIONS[from].includes(to);
}

export function transition(state: MatchState, to: MatchStatus, now: number): MatchState {
  if (!canTransition(state.status, to)) {
    throw new MatchError("INVALID_TRANSITION", `Cannot move match from ${state.status} to ${to}`);
  }
  return { ...state, status: to, completedAt: to === "COMPLETED" ? now : state.completedAt };
}

export interface CreateMatchInput {
  id: string;
  mode: GameMode;
  playerKey: string;
  locale: Locale;
  category: CategorySelection;
  rulesetVersion: string;
  questions: MatchQuestion[];
  now: number;
}

/** Solo modes go straight from CREATED to ACTIVE. */
export function createSoloMatch(input: CreateMatchInput): MatchState {
  if (input.questions.length === 0) throw new MatchError("INVALID_ANSWER", "A match needs questions");
  const created: MatchState = {
    id: input.id,
    mode: input.mode,
    status: "CREATED",
    playerKey: input.playerKey,
    locale: input.locale,
    category: input.category,
    rulesetVersion: input.rulesetVersion,
    questions: input.questions,
    currentIndex: 0,
    currentIssuedAt: null,
    answers: [],
    score: 0,
    streak: 0,
    bestStreak: 0,
    createdAt: input.now,
    completedAt: null,
    version: 0,
  };
  return transition(created, "ACTIVE", input.now);
}

function lastActivity(state: MatchState): number {
  const lastAnswer = state.answers[state.answers.length - 1]?.answeredAt ?? 0;
  return Math.max(state.createdAt, state.currentIssuedAt ?? 0, lastAnswer);
}

export function isStale(state: MatchState, now: number): boolean {
  return state.status === "ACTIVE" && now - lastActivity(state) > MATCH_TTL_MS;
}

/** Expires a stale active match; returns the same object when nothing changes. */
export function expireIfStale(state: MatchState, now: number): MatchState {
  return isStale(state, now) ? transition(state, "EXPIRED", now) : state;
}

/**
 * Marks the current question as delivered. The first delivery fixes the timer:
 * re-fetching (refresh, reconnect) never grants extra time.
 */
export function deliverCurrentQuestion(state: MatchState, now: number): MatchState {
  if (state.status !== "ACTIVE") throw new MatchError("NOT_ACTIVE", "Match is not active");
  if (state.currentIssuedAt !== null) return state;
  return { ...state, currentIssuedAt: now };
}

export interface SubmitInput {
  questionIndex: number;
  /** Display index 0–3, or null to report a timeout. */
  selectedIndex: number | null;
  now: number;
}

export interface SubmitResult {
  state: MatchState;
  feedback: AnswerFeedback;
  /** True when this exact question was already answered: no state change. */
  duplicate: boolean;
}

function feedbackFrom(state: MatchState, record: AnswerRecord, duplicate: boolean): AnswerFeedback {
  return {
    questionIndex: record.questionIndex,
    correct: record.correct,
    timedOut: record.timedOut,
    selectedIndex: record.selectedIndex,
    correctIndex: state.questions[record.questionIndex].correctDisplayIndex,
    points: record.points,
    speedBonus: record.speedBonus,
    multiplier: record.multiplier,
    score: state.score,
    streak: record.streakAfter,
    duplicate,
  };
}

/**
 * Validates and scores one answer using server time only. Re-submitting an
 * already answered question is idempotent and returns the original result.
 */
export function submitAnswer(state: MatchState, input: SubmitInput): SubmitResult {
  const existing = state.answers.find((a) => a.questionIndex === input.questionIndex);
  if (existing) return { state, feedback: feedbackFrom(state, existing, true), duplicate: true };

  if (state.status !== "ACTIVE") throw new MatchError("NOT_ACTIVE", "Match is not active");
  if (isStale(state, input.now)) throw new MatchError("EXPIRED", "Match expired");
  if (input.questionIndex !== state.currentIndex) {
    throw new MatchError("OUT_OF_ORDER", "Answer does not match the current question");
  }
  if (state.currentIssuedAt === null) throw new MatchError("NOT_DELIVERED", "Question was not delivered yet");
  if (input.selectedIndex !== null && !(Number.isInteger(input.selectedIndex) && input.selectedIndex >= 0 && input.selectedIndex <= 3)) {
    throw new MatchError("INVALID_ANSWER", "Answer index must be between 0 and 3");
  }

  const rules = getRuleset(state.rulesetVersion);
  const slot = state.questions[state.currentIndex];
  const elapsedMs = Math.max(0, input.now - state.currentIssuedAt);
  const timedOut = input.selectedIndex === null || isLate(elapsedMs, rules);
  const correct = !timedOut && input.selectedIndex === slot.correctDisplayIndex;
  const outcome = scoreAnswer(
    { difficulty: slot.difficulty, correct, timedOut, elapsedMs, previousStreak: state.streak },
    rules,
  );

  const record: AnswerRecord = {
    questionIndex: state.currentIndex,
    selectedIndex: timedOut ? null : input.selectedIndex,
    correct,
    timedOut,
    elapsedMs: Math.min(elapsedMs, rules.timeLimitMs + rules.latencyGraceMs),
    points: outcome.points,
    basePoints: outcome.basePoints,
    speedBonus: outcome.speedBonus,
    multiplier: outcome.multiplier,
    streakAfter: outcome.streakAfter,
    answeredAt: input.now,
  };

  let next: MatchState = {
    ...state,
    answers: [...state.answers, record],
    score: state.score + outcome.points,
    streak: outcome.streakAfter,
    bestStreak: Math.max(state.bestStreak, outcome.streakAfter),
    currentIndex: state.currentIndex + 1,
    currentIssuedAt: null,
  };
  if (next.currentIndex >= next.questions.length) next = transition(next, "COMPLETED", input.now);

  return { state: next, feedback: feedbackFrom(next, record, false), duplicate: false };
}

/** Client-safe view of the current question. Never includes the correct answer. */
export function toPublicQuestion(state: MatchState, question: Question, now: number): PublicQuestion {
  const slot = state.questions[state.currentIndex];
  if (!slot || slot.questionId !== question.id) throw new Error("Question does not match current slot");
  const rules = getRuleset(state.rulesetVersion);
  const issuedAt = state.currentIssuedAt ?? now;
  return {
    index: state.currentIndex,
    total: state.questions.length,
    category: slot.category,
    difficulty: slot.difficulty,
    text: question.text,
    options: slot.optionOrder.map((c) => question.options[c]),
    timeLimitMs: rules.timeLimitMs,
    remainingMs: Math.max(0, rules.timeLimitMs - (now - issuedAt)),
  };
}
