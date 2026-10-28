"use client";

import { create } from "zustand";
import { ApiError, gameApi } from "@/features/gameplay/client-api";
import type { AnswerFeedback, CategorySelection, GameMode, Locale, MatchResults, PublicQuestion } from "@/types/game";

/**
 * Client-side view of a match. The server owns the truth (timer, scoring,
 * correct answers); this store only mirrors what the API returns.
 */
export type GamePhase =
  | "setup"
  | "countdown"
  | "starting"
  | "question"
  | "submitting"
  | "feedback"
  | "loadingNext"
  | "loadingResults"
  | "results"
  | "error";

export type SlotResult = "correct" | "wrong" | "timeout";

interface GameState {
  phase: GamePhase;
  mode: GameMode;
  category: CategorySelection;
  matchId: string | null;
  question: PublicQuestion | null;
  /** performance.now() timestamp at which the current question expires on the client. */
  deadline: number | null;
  selected: number | null;
  feedback: AnswerFeedback | null;
  completed: boolean;
  score: number;
  streak: number;
  slots: SlotResult[];
  results: MatchResults | null;
  errorCode: string | null;

  /** Resets the match and starts the 3-2-1 countdown for the given mode/category. */
  beginCountdown: (mode?: GameMode, category?: CategorySelection) => void;
  start: (locale: Locale) => Promise<void>;
  answer: (index: number | null) => Promise<void>;
  advance: () => Promise<void>;
  reset: () => void;
}

const initial = {
  phase: "setup" as GamePhase,
  matchId: null,
  question: null,
  deadline: null,
  selected: null,
  feedback: null,
  completed: false,
  score: 0,
  streak: 0,
  slots: [] as SlotResult[],
  results: null,
  errorCode: null,
};

const now = () => (typeof performance !== "undefined" ? performance.now() : Date.now());
const codeOf = (err: unknown) => (err instanceof ApiError ? err.code : "UNKNOWN");

export const useGame = create<GameState>()((set, get) => ({
  ...initial,
  mode: "quick_play",
  category: "mixed",

  beginCountdown: (mode, category) =>
    set((s) => ({ ...initial, phase: "countdown", mode: mode ?? s.mode, category: category ?? s.category })),

  start: async (locale) => {
    set({ phase: "starting" });
    try {
      const { matchId, question } = await gameApi.start(locale, get().category, get().mode);
      set({ matchId, question, deadline: now() + question.remainingMs, phase: "question" });
    } catch (err) {
      set({ phase: "error", errorCode: codeOf(err) });
    }
  },

  answer: async (index) => {
    const { phase, matchId, question } = get();
    if (phase !== "question" || !matchId || !question) return;
    set({ phase: "submitting", selected: index });
    try {
      const { feedback, completed } = await gameApi.answer(matchId, question.index, index);
      const result: SlotResult = feedback.correct ? "correct" : feedback.timedOut ? "timeout" : "wrong";
      set((s) => ({
        phase: "feedback",
        feedback,
        completed,
        score: feedback.score,
        streak: feedback.streak,
        slots: [...s.slots.slice(0, feedback.questionIndex), result],
      }));
    } catch (err) {
      set({ phase: "error", errorCode: codeOf(err) });
    }
  },

  advance: async () => {
    const { phase, matchId, completed } = get();
    if (phase !== "feedback" || !matchId) return;
    if (completed) {
      set({ phase: "loadingResults" });
      try {
        set({ results: await gameApi.results(matchId), phase: "results" });
      } catch (err) {
        set({ phase: "error", errorCode: codeOf(err) });
      }
      return;
    }
    set({ phase: "loadingNext" });
    try {
      const snap = await gameApi.current(matchId);
      if (!snap.question) {
        set({ phase: "error", errorCode: snap.status === "EXPIRED" ? "EXPIRED" : "UNKNOWN" });
        return;
      }
      set({
        question: snap.question,
        deadline: now() + snap.question.remainingMs,
        selected: null,
        feedback: null,
        score: snap.score,
        streak: snap.streak,
        phase: "question",
      });
    } catch (err) {
      set({ phase: "error", errorCode: codeOf(err) });
    }
  },

  reset: () => set({ ...initial }),
}));
