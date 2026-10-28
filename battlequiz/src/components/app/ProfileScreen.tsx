"use client";

import { Check, Clock, Crown, Flame, Gamepad2, Pencil, Settings, Target } from "lucide-react";
import { motion } from "motion/react";
import { CATEGORY_COLORS, CategoryIcon } from "@/components/game/CategoryIcon";
import { levelFromXp } from "@/features/progression/levels";
import { averageAccuracy } from "@/features/progression/player";
import { fmt, useMessages } from "@/i18n";
import { useNav } from "@/stores/nav";
import { usePlayer } from "@/stores/player";
import { QUESTION_CATEGORIES } from "@/types/game";
import { MatchRow } from "./MatchRow";
import { Avatar, Pressable, ProgressBar, SectionTitle, timeAgo } from "./primitives";
import { useNow } from "./shared";

export function ProfileScreen() {
  const { m, locale } = useMessages();
  const now = useNow();
  const push = useNav((s) => s.push);
  const { nickname, avatarColor, progress } = usePlayer();
  const level = levelFromXp(progress.xp);
  const name = nickname || m.app.defaultName;
  const stats = [
    { icon: Gamepad2, label: m.app.profile.matches, value: progress.matches.toLocaleString(locale), color: "#a78bfa" },
    { icon: Target, label: m.app.profile.accuracy, value: `${Math.round(averageAccuracy(progress) * 100)}%`, color: "#06b6d4" },
    { icon: Check, label: m.app.profile.correct, value: progress.correct.toLocaleString(locale), color: "#22c55e" },
    { icon: Crown, label: m.app.profile.bestScore, value: progress.bestScore.toLocaleString(locale), color: "#fbbf24" },
    { icon: Flame, label: m.app.profile.bestStreak, value: String(progress.bestStreak), color: "#fb923c" },
    { icon: Clock, label: m.app.profile.avgTime, value: progress.answered ? `${(progress.totalResponseMs / progress.answered / 1000).toFixed(1)}s` : "–", color: "#f472b6" },
  ];
  const categories = QUESTION_CATEGORIES.map((c) => ({ c, s: progress.categories[c] })).filter((x) => x.s && x.s.answered > 0).sort((a, b) => b.s!.correct / b.s!.answered - a.s!.correct / a.s!.answered);

  return (
    <div className="pb-6">
      <div className="relative overflow-hidden px-4 pb-6 pt-3">
        <div className="absolute inset-x-0 top-0 h-48 opacity-60" style={{ background: `radial-gradient(ellipse at 50% 0%, ${avatarColor}, transparent 70%)` }} />
        <div className="relative flex justify-end">
          <Pressable onClick={() => push({ name: "settings" })} aria-label={m.app.settings} className="grid h-11 w-11 place-items-center rounded-full bg-white/10">
            <Settings className="h-5 w-5" />
          </Pressable>
        </div>
        <div className="relative flex flex-col items-center text-center">
          <motion.div initial={{ scale: 0.8, opacity: 0 }} animate={{ scale: 1, opacity: 1 }}>
            <Avatar name={name} color={avatarColor} size={96} />
          </motion.div>
          <Pressable onClick={() => push({ name: "settings" })} className="mt-3 flex items-center gap-2" aria-label={m.app.profile.edit}>
            <span className="font-display text-2xl font-black" data-testid="profile-name">{name}</span>
            <Pencil className="h-4 w-4 text-muted" />
          </Pressable>
          <span className="mt-1 rounded-full bg-primary/20 px-3 py-1 text-xs font-bold text-primary-soft">{fmt(m.app.level, { level: level.level })}</span>
          <div className="mt-4 w-full max-w-xs">
            <ProgressBar value={level.progress} />
            <p className="mt-1.5 text-xs font-semibold text-muted tabular-nums">{fmt(m.app.xpProgress, { xp: level.xpIntoLevel, next: level.xpForNext })}</p>
          </div>
        </div>
      </div>

      <div className="px-4">
        <SectionTitle>{m.app.profile.stats}</SectionTitle>
        <div className="grid grid-cols-3 gap-2.5">
          {stats.map(({ icon: Icon, label, value, color }) => (
            <div key={label} className="rounded-2xl bg-surface p-3 ring-1 ring-white/10">
              <Icon className="h-5 w-5" style={{ color }} />
              <p className="mt-2 font-display text-lg font-extrabold tabular-nums">{value}</p>
              <p className="text-[11px] leading-tight text-muted">{label}</p>
            </div>
          ))}
        </div>

        <SectionTitle>{m.app.profile.categoryTitle}</SectionTitle>
        {categories.length === 0 ? (
          <p className="rounded-3xl bg-white/5 p-5 text-center text-sm text-muted ring-1 ring-white/10">{m.app.profile.categoryEmpty}</p>
        ) : (
          <div className="space-y-3 rounded-3xl bg-surface p-4 ring-1 ring-white/10">
            {categories.map(({ c, s }) => {
              const acc = s!.correct / s!.answered;
              return (
                <div key={c} className="flex items-center gap-3">
                  <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl" style={{ background: `${CATEGORY_COLORS[c]}26`, color: CATEGORY_COLORS[c] }}>
                    <CategoryIcon category={c} className="h-4 w-4" />
                  </span>
                  <div className="flex-1">
                    <div className="flex justify-between text-sm">
                      <span className="font-semibold">{m.categories[c]}</span>
                      <span className="font-bold tabular-nums">{Math.round(acc * 100)}%</span>
                    </div>
                    <div className="mt-1.5 h-2 overflow-hidden rounded-full bg-white/10">
                      <motion.div initial={{ width: 0 }} animate={{ width: `${acc * 100}%` }} transition={{ duration: 0.8 }} className="h-full rounded-full" style={{ background: CATEGORY_COLORS[c] }} />
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}

        <SectionTitle action={progress.history.length > 5 && <button type="button" onClick={() => push({ name: "history" })} className="text-sm font-semibold text-primary-soft">{m.app.seeAll}</button>}>
          {m.app.profile.historyTitle}
        </SectionTitle>
        {progress.history.length === 0 ? (
          <p className="rounded-3xl bg-white/5 p-5 text-center text-sm text-muted ring-1 ring-white/10">{m.app.noMatches}</p>
        ) : (
          <div className="space-y-2">
            {progress.history.slice(0, 5).map((h) => (
              <MatchRow key={h.id} match={h} when={timeAgo(h.at, now, m.app.ago)} />
            ))}
          </div>
        )}
        <p className="mt-6 text-center text-xs text-muted">{m.app.profile.localNote}</p>
      </div>
    </div>
  );
}
