import { randomUUID } from "node:crypto";
import { matchXp } from "@/features/progression/levels";
import { buildMatchQuestions, QUICK_PLAY_LENGTH, selectQuestions } from "@/features/questions/selection";
import { createRng, type Rng } from "@/lib/random";
import { CURRENT_RULESET, summarizeAnswers } from "@/lib/scoring";
import type { Repositories } from "@/lib/store/types";
import {
  QUESTION_CATEGORIES,
  type AnswerFeedback,
  type CategorySelection,
  type Locale,
  type MatchResults,
  type MatchState,
  type MatchStatus,
  type PublicQuestion,
  type QuestionCategory,
} from "@/types/game";
import { deliverCurrentQuestion, expireIfStale, MatchError, submitAnswer, toPublicQuestion, createSoloMatch } from "./engine";

/** How many recently seen questions are deprioritised when building a match. */
const HISTORY_WINDOW = 120;
/** Max attempts when a concurrent write wins the optimistic-concurrency race. */
const MAX_WRITE_ATTEMPTS = 4;
/** Correct answers faster than this are physically implausible for reading + tapping. */
const SUSPICIOUS_ANSWER_MS = 350;

export class GameServiceError extends Error {
  constructor(
    public readonly code: "NOT_FOUND" | "NOT_COMPLETED" | "CONFLICT" | "NO_QUESTIONS" | MatchError["code"],
    message: string,
    public readonly status: number,
  ) {
    super(message);
    this.name = "GameServiceError";
  }
}

function fromMatchError(err: unknown): never {
  if (err instanceof MatchError) {
    const status = err.code === "EXPIRED" || err.code === "NOT_ACTIVE" ? 409 : 400;
    throw new GameServiceError(err.code, err.message, status);
  }
  throw err;
}

/** Loads a match the caller owns. Other players' matches are indistinguishable from missing ones. */
async function loadOwned(repos: Repositories, matchId: string, playerKey: string): Promise<MatchState> {
  const state = await repos.matches.get(matchId);
  if (!state || state.playerKey !== playerKey) throw new GameServiceError("NOT_FOUND", "Match not found", 404);
  return state;
}

/** Read–modify–write with optimistic concurrency and bounded retries. */
async function mutate<T>(
  repos: Repositories,
  matchId: string,
  playerKey: string,
  fn: (state: MatchState) => { next: MatchState; result: T },
): Promise<T> {
  for (let attempt = 0; attempt < MAX_WRITE_ATTEMPTS; attempt++) {
    const state = await loadOwned(repos, matchId, playerKey);
    let out: { next: MatchState; result: T };
    try {
      out = fn(state);
    } catch (err) {
      fromMatchError(err);
    }
    if (out.next === state) return out.result;
    if (await repos.matches.save(out.next, state.version)) return out.result;
  }
  throw new GameServiceError("CONFLICT", "Concurrent update, please retry", 409);
}

export async function availableCategories(repos: Repositories, locale: Locale): Promise<QuestionCategory[]> {
  const counts = await repos.questions.countByCategory(locale);
  return QUESTION_CATEGORIES.filter((c) => counts[c] >= QUICK_PLAY_LENGTH);
}

export interface StartInput {
  playerKey: string;
  locale: Locale;
  category: CategorySelection;
  now: number;
  rng?: Rng;
  matchId?: string;
}

export async function startQuickPlay(
  repos: Repositories,
  input: StartInput,
): Promise<{ matchId: string; question: PublicQuestion }> {
  const matchId = input.matchId ?? randomUUID();
  const rng = input.rng ?? createRng(`${matchId}:${input.now}`);
  const [pool, recentlySeen] = await Promise.all([
    repos.questions.listPlayable(input.locale),
    repos.history.recent(input.playerKey, HISTORY_WINDOW),
  ]);

  let picked;
  try {
    picked = selectQuestions({ pool, category: input.category, recentlySeen, rng });
  } catch {
    throw new GameServiceError("NO_QUESTIONS", "Not enough questions for this category", 422);
  }

  const created = createSoloMatch({
    id: matchId,
    mode: "quick_play",
    playerKey: input.playerKey,
    locale: input.locale,
    category: input.category,
    rulesetVersion: CURRENT_RULESET.version,
    questions: buildMatchQuestions(picked, rng),
    now: input.now,
  });
  // The first question is delivered as part of creation, which starts its timer.
  const state = deliverCurrentQuestion(created, input.now);
  await repos.matches.create(state);
  await repos.history.record(input.playerKey, picked.map((q) => q.id), input.now);
  await repos.audit.log({ actorKey: input.playerKey, action: "match.created", subject: matchId, metadata: { mode: "quick_play", category: input.category } });

  return { matchId, question: toPublicQuestion(state, picked[0], input.now) };
}

export interface MatchSnapshot {
  matchId: string;
  status: MatchStatus;
  score: number;
  streak: number;
  answered: number;
  total: number;
  question: PublicQuestion | null;
}

/** Returns (and delivers, starting its timer) the current question. Safe to call repeatedly. */
export async function getCurrentQuestion(
  repos: Repositories,
  input: { matchId: string; playerKey: string; now: number },
): Promise<MatchSnapshot> {
  const state = await mutate(repos, input.matchId, input.playerKey, (s) => {
    const expired = expireIfStale(s, input.now);
    const next = expired.status === "ACTIVE" ? deliverCurrentQuestion(expired, input.now) : expired;
    return { next, result: next };
  });

  let question: PublicQuestion | null = null;
  if (state.status === "ACTIVE") {
    const slot = state.questions[state.currentIndex];
    const q = (await repos.questions.getByIds([slot.questionId])).get(slot.questionId);
    if (!q) throw new GameServiceError("NO_QUESTIONS", "Question no longer available", 410);
    question = toPublicQuestion(state, q, input.now);
  }
  return {
    matchId: state.id,
    status: state.status,
    score: state.score,
    streak: state.streak,
    answered: state.answers.length,
    total: state.questions.length,
    question,
  };
}

export async function answerQuestion(
  repos: Repositories,
  input: { matchId: string; playerKey: string; questionIndex: number; selectedIndex: number | null; now: number },
): Promise<{ feedback: AnswerFeedback; completed: boolean }> {
  const out = await mutate(repos, input.matchId, input.playerKey, (s) => {
    const r = submitAnswer(s, { questionIndex: input.questionIndex, selectedIndex: input.selectedIndex, now: input.now });
    return { next: r.state, result: { feedback: r.feedback, completed: r.state.status === "COMPLETED", duplicate: r.duplicate, state: r.state } };
  });

  if (out.completed && !out.duplicate) {
    const fast = out.state.answers.filter((a) => a.correct && a.elapsedMs < SUSPICIOUS_ANSWER_MS).length;
    await repos.audit.log({
      actorKey: input.playerKey,
      action: "match.completed",
      subject: input.matchId,
      metadata: { score: out.state.score, correct: out.state.answers.filter((a) => a.correct).length },
    });
    if (fast >= 3) {
      await repos.audit.log({ actorKey: input.playerKey, action: "abuse.suspicious_fast_answers", subject: input.matchId, metadata: { fast } });
    }
  }
  return { feedback: out.feedback, completed: out.completed };
}

/** Full results with the correct answers and explanations; only after completion. */
export async function getResults(
  repos: Repositories,
  input: { matchId: string; playerKey: string },
): Promise<MatchResults> {
  const state = await loadOwned(repos, input.matchId, input.playerKey);
  if (state.status !== "COMPLETED") throw new GameServiceError("NOT_COMPLETED", "Match is not completed", 409);
  const questions = await repos.questions.getByIds(state.questions.map((q) => q.questionId));
  const summary = summarizeAnswers(state.answers, state.questions.length);

  return {
    matchId: state.id,
    status: state.status,
    score: summary.score,
    correctCount: summary.correctCount,
    totalQuestions: state.questions.length,
    accuracy: summary.accuracy,
    bestStreak: summary.bestStreak,
    averageResponseMs: summary.averageResponseMs,
    xpEarned: matchXp(summary.correctCount, state.questions.length, true),
    rulesetVersion: state.rulesetVersion,
    review: state.questions.map((slot, index) => {
      const q = questions.get(slot.questionId);
      const a = state.answers.find((x) => x.questionIndex === index);
      return {
        index,
        category: slot.category,
        difficulty: slot.difficulty,
        text: q?.text ?? "",
        options: q ? slot.optionOrder.map((c) => q.options[c]) : [],
        correctIndex: slot.correctDisplayIndex,
        selectedIndex: a?.selectedIndex ?? null,
        correct: a?.correct ?? false,
        timedOut: a?.timedOut ?? true,
        points: a?.points ?? 0,
        explanation: q?.explanation ?? "",
      };
    }),
  };
}
