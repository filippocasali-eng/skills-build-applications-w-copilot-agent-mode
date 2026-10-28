import type { PlayerProgress } from "@/features/progression/player";

/**
 * Achievement catalogue. Each achievement exposes a numeric progress value and a
 * target; it unlocks once value >= target. Multiplayer achievements stay locked
 * until battles exist (Milestones 3–4).
 */
export type AchievementIcon =
  | "trophy"
  | "star"
  | "gamepad"
  | "check"
  | "zap"
  | "globe"
  | "flask"
  | "flame"
  | "calendar"
  | "medal"
  | "sun";

export interface AchievementDef {
  id: string;
  icon: AchievementIcon;
  target: number;
  xpReward: number;
  /** Needs head-to-head battles; cannot unlock in solo play. */
  multiplayer?: boolean;
  value: (p: PlayerProgress) => number;
}

export const ACHIEVEMENTS: readonly AchievementDef[] = [
  { id: "first_victory", icon: "trophy", target: 1, xpReward: 25, multiplayer: true, value: (p) => p.wins },
  { id: "perfect_match", icon: "star", target: 1, xpReward: 50, value: (p) => p.perfectMatches },
  { id: "matches_10", icon: "gamepad", target: 10, xpReward: 25, value: (p) => p.matches },
  { id: "correct_100", icon: "check", target: 100, xpReward: 50, value: (p) => p.correct },
  { id: "speed_demon", icon: "zap", target: 5, xpReward: 50, value: (p) => p.bestFastAnswers },
  { id: "geography_expert", icon: "globe", target: 50, xpReward: 50, value: (p) => p.categories.geography?.correct ?? 0 },
  { id: "science_master", icon: "flask", target: 50, xpReward: 50, value: (p) => p.categories.science?.correct ?? 0 },
  { id: "win_streak_5", icon: "flame", target: 5, xpReward: 75, multiplayer: true, value: (p) => p.bestWinStreak },
  { id: "daily_challenger", icon: "calendar", target: 1, xpReward: 25, value: (p) => p.dailyCompleted },
  { id: "quiz_veteran", icon: "medal", target: 100, xpReward: 100, value: (p) => p.matches },
  { id: "daily_streak_7", icon: "sun", target: 7, xpReward: 75, value: (p) => p.bestDayStreak },
];

export function achievementProgress(def: AchievementDef, p: PlayerProgress): number {
  return Math.min(1, def.value(p) / def.target);
}

/** Achievements that are complete in `p` but not yet recorded as unlocked. */
export function newlyUnlocked(p: PlayerProgress): AchievementDef[] {
  return ACHIEVEMENTS.filter((a) => !p.achievements[a.id] && a.value(p) >= a.target);
}
