"use client";

import { create } from "zustand";
import { createJSONStorage, persist } from "zustand/middleware";
import { DEFAULT_LOCALE, type Locale } from "@/types/game";

export type MotionPreference = "system" | "reduce" | "full";

interface SettingsState {
  locale: Locale;
  soundOn: boolean;
  motion: MotionPreference;
  setLocale: (l: Locale) => void;
  toggleSound: () => void;
  setMotion: (m: MotionPreference) => void;
}

/** Per-device preferences. Stored in localStorage; safe to lose. */
export const useSettings = create<SettingsState>()(
  persist(
    (set) => ({
      locale: DEFAULT_LOCALE,
      // Sound starts off: browsers block autoplay and many players are in public places.
      soundOn: false,
      motion: "system",
      setLocale: (locale) => set({ locale }),
      toggleSound: () => set((s) => ({ soundOn: !s.soundOn })),
      setMotion: (motion) => set({ motion }),
    }),
    { name: "bq-settings", storage: createJSONStorage(() => localStorage), version: 1 },
  ),
);
