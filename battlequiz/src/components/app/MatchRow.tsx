"use client";

import { CalendarDays } from "lucide-react";
import { CATEGORY_COLORS, CategoryIcon } from "@/components/game/CategoryIcon";
import type { MatchSummary } from "@/features/progression/player";
import { useMessages } from "@/i18n";

export function MatchRow({ match, when }: { match: MatchSummary; when: string }) {
  const { m, locale } = useMessages();
  const daily = match.mode === "daily_challenge";
  const color = daily ? "#06b6d4" : CATEGORY_COLORS[match.category];
  return (
    <div className="flex items-center gap-3 rounded-2xl bg-surface p-3 ring-1 ring-white/10">
      <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl" style={{ background: `${color}26`, color }}>
        {daily ? <CalendarDays className="h-5 w-5" /> : <CategoryIcon category={match.category} className="h-5 w-5" />}
      </span>
      <span className="min-w-0 flex-1">
        <span className="block truncate text-sm font-bold">{daily ? m.app.modeLabel.daily_challenge : m.categories[match.category]}</span>
        <span className="block text-xs text-muted">
          {match.correct}/{match.total} · {when}
        </span>
      </span>
      <span className="text-right">
        <span className="block font-display font-extrabold tabular-nums text-gold">{match.score.toLocaleString(locale)}</span>
        <span className="block text-[11px] font-semibold text-secondary">+{match.xp} XP</span>
      </span>
    </div>
  );
}
