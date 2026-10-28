"use client";

import { Check, Crown, Flame, Lock, Trophy, Zap } from "lucide-react";
import { motion } from "motion/react";
import { ACHIEVEMENTS, achievementProgress } from "@/features/achievements/catalog";
import { fmt, useMessages } from "@/i18n";
import { cn } from "@/lib/utils";
import { usePlayer } from "@/stores/player";
import { ProgressBar, SectionTitle } from "./primitives";
import { AchievementBadge } from "./shared";

export function TrophiesScreen() {
  const { m, locale } = useMessages();
  const progress = usePlayer((s) => s.progress);
  const unlockedCount = ACHIEVEMENTS.filter((a) => progress.achievements[a.id]).length;
  const sorted = [...ACHIEVEMENTS].sort((a, b) => {
    const ua = progress.achievements[a.id] ? 1 : 0;
    const ub = progress.achievements[b.id] ? 1 : 0;
    if (ua !== ub) return ub - ua;
    if (!!a.multiplayer !== !!b.multiplayer) return a.multiplayer ? 1 : -1;
    return achievementProgress(b, progress) - achievementProgress(a, progress);
  });
  const records = [
    { icon: Crown, label: m.app.profile.bestScore, value: progress.bestScore.toLocaleString(locale), color: "text-gold" },
    { icon: Flame, label: m.app.profile.bestStreak, value: String(progress.bestStreak), color: "text-[#fb923c]" },
    { icon: Zap, label: m.app.profile.dayStreak, value: String(progress.bestDayStreak), color: "text-secondary" },
  ];

  return (
    <div className="px-4 pb-6">
      <h1 className="pt-3 font-display text-3xl font-black">{m.app.trophies.title}</h1>
      <div className="relative mt-4 overflow-hidden rounded-[2rem] bg-gradient-to-br from-[#b45309] via-[#92400e] to-[#451a03] p-5 ring-1 ring-gold/40">
        <Trophy className="absolute -right-4 -top-4 h-36 w-36 rotate-12 text-gold/20" />
        <p className="relative font-display text-4xl font-black" data-testid="trophy-count">
          {unlockedCount}
          <span className="text-2xl text-white/60">/{ACHIEVEMENTS.length}</span>
        </p>
        <p className="relative text-sm font-semibold text-white/80">{fmt(m.app.trophies.unlocked, { n: unlockedCount, total: ACHIEVEMENTS.length })}</p>
        <ProgressBar value={unlockedCount / ACHIEVEMENTS.length} className="relative mt-3 bg-black/25" color="from-[#fde68a] to-gold" />
      </div>

      <SectionTitle>{m.app.trophies.records}</SectionTitle>
      <div className="grid grid-cols-3 gap-2.5">
        {records.map(({ icon: Icon, label, value, color }) => (
          <div key={label} className="rounded-2xl bg-surface p-3 text-center ring-1 ring-white/10">
            <Icon className={cn("mx-auto h-5 w-5", color)} />
            <p className="mt-1 font-display text-lg font-extrabold tabular-nums">{value}</p>
            <p className="text-[11px] leading-tight text-muted">{label}</p>
          </div>
        ))}
      </div>

      <SectionTitle>{m.app.trophies.title}</SectionTitle>
      <ul className="space-y-2.5">
        {sorted.map((a, i) => {
          const at = progress.achievements[a.id];
          const text = m.achievements[a.id as keyof typeof m.achievements];
          const pct = achievementProgress(a, progress);
          return (
            <motion.li key={a.id} initial={{ opacity: 0, x: -10 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: 0.03 * i }} className={cn("flex items-center gap-4 rounded-3xl p-4 ring-1", at ? "bg-gold/10 ring-gold/30" : "bg-surface ring-white/10")}>
              <AchievementBadge icon={a.icon} unlocked={!!at} />
              <div className="min-w-0 flex-1">
                <div className="flex items-center justify-between gap-2">
                  <p className="truncate font-bold">{text.name}</p>
                  <span className="shrink-0 text-xs font-bold text-secondary">{fmt(m.app.trophies.reward, { xp: a.xpReward })}</span>
                </div>
                <p className="text-xs text-muted">{text.desc}</p>
                {at ? (
                  <p className="mt-1.5 flex items-center gap-1 text-xs font-semibold text-gold">
                    <Check className="h-3.5 w-3.5" /> {fmt(m.app.trophies.unlockedOn, { date: new Date(at).toLocaleDateString(locale) })}
                  </p>
                ) : a.multiplayer ? (
                  <p className="mt-1.5 flex items-center gap-1 text-xs text-muted">
                    <Lock className="h-3.5 w-3.5" /> {m.app.trophies.multiplayer}
                  </p>
                ) : (
                  <div className="mt-2 flex items-center gap-2">
                    <ProgressBar value={pct} className="h-1.5 flex-1" color="from-gold to-[#f59e0b]" />
                    <span className="text-[11px] font-semibold tabular-nums text-muted">
                      {Math.min(a.value(progress), a.target)}/{a.target}
                    </span>
                  </div>
                )}
              </div>
            </motion.li>
          );
        })}
      </ul>
    </div>
  );
}
