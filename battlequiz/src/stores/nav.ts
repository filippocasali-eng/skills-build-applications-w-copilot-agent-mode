"use client";

import { create } from "zustand";
import type { CategorySelection, GameMode } from "@/types/game";

/**
 * In-app navigation: four tabs plus a stack of full-screen pages on top.
 * The stack mirrors browser history so the Android back button and the browser
 * back gesture both pop screens (see useHistorySync in AppShell).
 */
export type Tab = "home" | "play" | "trophies" | "profile";

export type Screen =
  | { name: "match"; mode: GameMode; category: CategorySelection }
  | { name: "settings" }
  | { name: "history" };

interface NavState {
  tab: Tab;
  stack: Screen[];
  setTab: (t: Tab) => void;
  push: (s: Screen) => void;
  /** Replaces the top screen (e.g. "play again"). */
  replace: (s: Screen) => void;
  pop: () => void;
  popToRoot: (tab?: Tab) => void;
}

export const useNav = create<NavState>()((set) => ({
  tab: "home",
  stack: [],
  setTab: (tab) => set({ tab }),
  push: (s) => set((st) => ({ stack: [...st.stack, s] })),
  replace: (s) => set((st) => ({ stack: [...st.stack.slice(0, -1), s] })),
  pop: () => set((st) => ({ stack: st.stack.slice(0, -1) })),
  popToRoot: (tab) => set((st) => ({ stack: [], tab: tab ?? st.tab })),
}));
