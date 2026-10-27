"use client";

import { create } from "zustand";
import { createJSONStorage, persist } from "zustand/middleware";
import type { MatchResults } from "@/types/game";

/**
 * TEMPORARY guest progression kept on this device only. It is a convenience
 * display; authoritative progression arrives with accounts (Milestone 2).
 */
interface GuestProfileState {
  xp: number;
  matchesPlayed: number;
  totalCorrect: number;
  bestScore: number;
  /** Match ids already credited, so a results reload never grants XP twice. */
  creditedMatches: string[];
  credit: (r: MatchResults) => { previousBest: number; previousXp: number; alreadyCredited: boolean };
}

export const useGuestProfile = create<GuestProfileState>()(
  persist(
    (set, get) => ({
      xp: 0,
      matchesPlayed: 0,
      totalCorrect: 0,
      bestScore: 0,
      creditedMatches: [],
      credit: (r) => {
        const s = get();
        if (s.creditedMatches.includes(r.matchId)) {
          return { previousBest: s.bestScore, previousXp: s.xp - r.xpEarned, alreadyCredited: true };
        }
        set({
          xp: s.xp + r.xpEarned,
          matchesPlayed: s.matchesPlayed + 1,
          totalCorrect: s.totalCorrect + r.correctCount,
          bestScore: Math.max(s.bestScore, r.score),
          creditedMatches: [...s.creditedMatches, r.matchId].slice(-50),
        });
        return { previousBest: s.bestScore, previousXp: s.xp, alreadyCredited: false };
      },
    }),
    { name: "bq-guest-profile", storage: createJSONStorage(() => localStorage), version: 1 },
  ),
);
