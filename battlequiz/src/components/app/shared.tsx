"use client";

import { Calendar, Check, FlaskConical, Flame, Gamepad2, Globe, Medal, Star, Sun, Trophy, Zap, type LucideIcon } from "lucide-react";
import { useEffect, useState } from "react";
import type { AchievementIcon } from "@/features/achievements/catalog";
import { cn } from "@/lib/utils";

export const ACHIEVEMENT_ICONS: Record<AchievementIcon, LucideIcon> = {
  trophy: Trophy,
  star: Star,
  gamepad: Gamepad2,
  check: Check,
  zap: Zap,
  globe: Globe,
  flask: FlaskConical,
  flame: Flame,
  calendar: Calendar,
  medal: Medal,
  sun: Sun,
};

export function AchievementBadge({ icon, unlocked, size = 52 }: { icon: AchievementIcon; unlocked: boolean; size?: number }) {
  const Icon = ACHIEVEMENT_ICONS[icon];
  return (
    <span
      aria-hidden="true"
      className={cn("grid shrink-0 place-items-center rounded-2xl", unlocked ? "bg-gradient-to-br from-[#fcd34d] to-[#f59e0b] text-[#3b2600] shadow-[0_8px_24px_-10px_rgb(251_191_36/0.9)]" : "bg-white/5 text-muted ring-1 ring-white/10")}
      style={{ width: size, height: size }}
    >
      <Icon style={{ width: size * 0.48, height: size * 0.48 }} />
    </span>
  );
}

/** Current time, refreshed every `ms` (for countdowns and "x min ago"). */
export function useNow(ms = 30_000): number {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), ms);
    return () => clearInterval(t);
  }, [ms]);
  return now;
}
