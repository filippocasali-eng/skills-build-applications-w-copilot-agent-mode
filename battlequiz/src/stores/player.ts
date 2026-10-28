"use client";

import { create } from "zustand";
import { createJSONStorage, persist } from "zustand/middleware";
import { applyMatch, EMPTY_PROGRESS, type ApplyResult, type PlayerProgress } from "@/features/progression/player";
import type { MatchResults } from "@/types/game";

/** Player profile and progression stored on this device (guest / offline app). */
export const AVATAR_COLORS = ["#7c3aed", "#06b6d4", "#f59e0b", "#22c55e", "#ef4444", "#ec4899", "#3b82f6", "#14b8a6"] as const;

interface PlayerState {
  nickname: string;
  avatarColor: string;
  onboarded: boolean;
  progress: PlayerProgress;
  setProfile: (p: { nickname?: string; avatarColor?: string }) => void;
  completeOnboarding: () => void;
  credit: (r: MatchResults) => ApplyResult;
  resetProgress: () => void;
}

export const usePlayer = create<PlayerState>()(
  persist(
    (set, get) => ({
      nickname: "",
      avatarColor: AVATAR_COLORS[0],
      onboarded: false,
      progress: EMPTY_PROGRESS,
      setProfile: (p) => set((s) => ({ nickname: (p.nickname ?? s.nickname).slice(0, 20), avatarColor: p.avatarColor ?? s.avatarColor })),
      completeOnboarding: () => set({ onboarded: true }),
      credit: (r) => {
        const result = applyMatch(get().progress, r, Date.now());
        if (!result.alreadyCredited) set({ progress: result.progress });
        return result;
      },
      resetProgress: () => set({ progress: EMPTY_PROGRESS }),
    }),
    {
      name: "bq-player",
      storage: createJSONStorage(() => localStorage),
      version: 1,
      // Fill fields added after a profile was first saved.
      merge: (persisted, current) => {
        const p = persisted as Partial<PlayerState>;
        return { ...current, ...p, progress: { ...EMPTY_PROGRESS, ...(p?.progress ?? {}) } };
      },
    },
  ),
);
