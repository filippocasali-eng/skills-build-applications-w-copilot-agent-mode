"use client";

import { CalendarCheck, CalendarDays, ChevronRight, Flame, Play, Settings, Sparkles, Zap } from "lucide-react";
import { motion } from "motion/react";
import { CATEGORY_COLORS, CategoryIcon } from "@/components/game/CategoryIcon";
import { ACHIEVEMENTS, achievementProgress } from "@/features/achievements/catalog";
import { utcDay } from "@/features/gameplay/service-time";
import { levelFromXp } from "@/features/progression/levels";
import { fmt, useMessages } from "@/i18n";
import { useNav } from "@/stores/nav";
import { usePlayer } from "@/stores/player";
import { QUESTION_CATEGORIES } from "@/types/game";
import { AchievementBadge, useNow } from "./shared";
import { Avatar, Pressable, ProgressBar, SectionTitle, timeAgo, untilUtcMidnight } from "./primitives";
import { MatchRow } from "./MatchRow";

const stagger = (i: number) => ({ initial: { opacity: 0, y: 16 }, animate: { opacity: 1, y: 0 }, transition: { delay: 0.04 * i, duration: 0.35 } });

export function HomeScreen() {
  const { m } = useMessages();
  const now = useNow();
  const push = useNav((s) => s.push);
  const setTab = useNav((s) => s.setTab);
  const { nickname, avatarColor, progress } = usePlayer();
  const level = levelFromXp(progress.xp);
  const name = nickname || m.app.defaultName;
  const hour = new Date(now).getHours();
  const greeting = hour < 12 ? m.app.greeting.morning : hour < 18 ? m.app.greeting.afternoon : m.app.greeting.evening;
  const today = utcDay(now);
  const dailyDone = progress.daily[today];
  const nextTrophy = ACHIEVEMENTS.filter((a) => !a.multiplayer && !progress.achievements[a.id]).sort((a, b) => achievementProgress(b, progress) - achievementProgress(a, progress))[0];

  return (
    <div className="px-4 pb-6">
      {/* Top bar */}
      <motion.div {...stagger(0)} className="flex items-center gap-3 pt-2">
        <Pressable onClick={() => setTab("profile")} aria-label={m.app.tabs.profile} className="rounded-full">
          <Avatar name={name} color={avatarColor} size={48} />
        </Pressable>
        <div className="min-w-0 flex-1">
          <p className="text-xs font-semibold text-muted">{greeting}</p>
          <p className="truncate font-display text-xl font-extrabold" data-testid="home-name">{name}</p>
        </div>
        {progress.dayStreak > 0 && (
          <span className="flex items-center gap-1 rounded-full bg-gold/15 px-3 py-1.5 font-display text-sm font-extrabold text-gold ring-1 ring-gold/30" aria-label={fmt(m.app.dayStreak, { n: progress.dayStreak })}>
            <Flame className="h-4 w-4 fill-current" /> {progress.dayStreak}
          </span>
        )}
        <Pressable onClick={() => push({ name: "settings" })} aria-label={m.app.settings} className="grid h-11 w-11 place-items-center rounded-full bg-white/5 ring-1 ring-white/10">
          <Settings className="h-5 w-5 text-muted" />
        </Pressable>
      </motion.div>

      {/* Level */}
      <motion.div {...stagger(1)} className="card-glass mt-5 flex items-center gap-4 rounded-3xl p-4">
        <div className="relative grid h-14 w-14 shrink-0 place-items-center">
          <svg viewBox="0 0 56 56" className="absolute inset-0 -rotate-90">
            <circle cx="28" cy="28" r="24" fill="none" stroke="rgb(255 255 255 / 0.1)" strokeWidth="5" />
            <motion.circle cx="28" cy="28" r="24" fill="none" stroke="url(#lvl)" strokeWidth="5" strokeLinecap="round" strokeDasharray={150.8} initial={{ strokeDashoffset: 150.8 }} animate={{ strokeDashoffset: 150.8 * (1 - level.progress) }} transition={{ duration: 1 }} />
            <defs>
              <linearGradient id="lvl" x1="0" x2="1">
                <stop offset="0" stopColor="#7c3aed" />
                <stop offset="1" stopColor="#06b6d4" />
              </linearGradient>
            </defs>
          </svg>
          <span className="font-display text-xl font-black">{level.level}</span>
        </div>
        <div className="flex-1">
          <div className="flex items-baseline justify-between">
            <span className="font-display font-bold">{fmt(m.app.level, { level: level.level })}</span>
            <span className="text-xs font-semibold text-muted tabular-nums">{fmt(m.app.xpProgress, { xp: level.xpIntoLevel, next: level.xpForNext })}</span>
          </div>
          <ProgressBar value={level.progress} className="mt-2" />
        </div>
      </motion.div>

      {/* Quick play hero */}
      <motion.div {...stagger(2)}>
        <Pressable
          haptics="select"
          data-testid="home-quick-play"
          onClick={() => push({ name: "match", mode: "quick_play", category: "mixed" })}
          className="relative mt-4 block w-full overflow-hidden rounded-[2rem] bg-gradient-to-br from-[#8b5cf6] via-primary to-[#4c1d95] p-6 shadow-[0_24px_60px_-24px_rgb(124_58_237/0.9)]"
        >
          <HeroArt />
          <span className="relative inline-flex items-center gap-1.5 rounded-full bg-white/15 px-2.5 py-1 text-[11px] font-bold uppercase tracking-wider">
            <Zap className="h-3.5 w-3.5 fill-current" /> 10 × 12s
          </span>
          <p className="relative mt-3 font-display text-3xl font-black leading-none">{m.app.quickPlay.title}</p>
          <p className="relative mt-2 max-w-[15rem] text-sm text-white/80">{m.app.quickPlay.subtitle}</p>
          <span className="relative mt-5 inline-flex items-center gap-2 rounded-2xl bg-white px-5 py-3 font-display font-extrabold text-primary shadow-lg">
            <Play className="h-5 w-5 fill-current" /> {m.app.quickPlay.cta}
          </span>
        </Pressable>
      </motion.div>

      {/* Daily challenge */}
      <motion.div {...stagger(3)}>
        <Pressable
          haptics="select"
          data-testid="home-daily"
          disabled={!!dailyDone}
          onClick={() => push({ name: "match", mode: "daily_challenge", category: "mixed" })}
          className="relative mt-3 flex w-full items-center gap-4 overflow-hidden rounded-3xl bg-gradient-to-br from-[#0e7490] to-[#164e63] p-5 ring-1 ring-secondary/40 disabled:cursor-default"
        >
          <span className="absolute -right-8 -top-8 h-28 w-28 rounded-full bg-secondary/30 blur-2xl" />
          <span className="relative grid h-14 w-14 shrink-0 place-items-center rounded-2xl bg-white/15">
            {dailyDone ? <CalendarCheck className="h-7 w-7 text-success" /> : <CalendarDays className="h-7 w-7" />}
          </span>
          <span className="relative min-w-0 flex-1">
            <span className="block font-display text-lg font-extrabold">{m.app.daily.title}</span>
            <span className="block text-sm text-white/75">
              {dailyDone ? fmt(m.app.daily.result, { score: dailyDone.score.toLocaleString(), correct: dailyDone.correct, total: dailyDone.total }) : m.app.daily.subtitle}
            </span>
            <span className="mt-1 block text-xs font-semibold text-secondary">{fmt(m.app.daily.nextIn, { time: untilUtcMidnight(now) })}</span>
          </span>
          {dailyDone ? (
            <span className="relative rounded-full bg-success/20 px-2.5 py-1 text-[11px] font-bold uppercase text-success">{m.app.daily.done}</span>
          ) : (
            <ChevronRight className="relative h-6 w-6 text-white/70" />
          )}
        </Pressable>
      </motion.div>

      {/* Categories carousel */}
      <SectionTitle>{m.app.categoriesTitle}</SectionTitle>
      <div className="no-scrollbar -mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1">
        {QUESTION_CATEGORIES.map((c) => (
          <Pressable
            key={c}
            onClick={() => push({ name: "match", mode: "quick_play", category: c })}
            className="flex w-24 shrink-0 snap-start flex-col items-center gap-2 rounded-3xl bg-surface p-3 ring-1 ring-white/10"
            aria-label={m.categories[c]}
          >
            <span className="grid h-14 w-14 place-items-center rounded-2xl" style={{ background: `linear-gradient(135deg, ${CATEGORY_COLORS[c]}55, ${CATEGORY_COLORS[c]}18)`, color: CATEGORY_COLORS[c] }}>
              <CategoryIcon category={c} className="h-7 w-7" />
            </span>
            <span className="line-clamp-2 text-center text-[11px] font-bold leading-tight">{m.categories[c]}</span>
          </Pressable>
        ))}
      </div>

      {/* Next trophy */}
      <SectionTitle>{m.app.nextTrophy}</SectionTitle>
      <Pressable onClick={() => setTab("trophies")} className="card-glass flex w-full items-center gap-4 rounded-3xl p-4">
        {nextTrophy ? (
          <>
            <AchievementBadge icon={nextTrophy.icon} unlocked={false} />
            <span className="min-w-0 flex-1">
              <span className="block font-bold">{m.achievements[nextTrophy.id as keyof typeof m.achievements].name}</span>
              <span className="block truncate text-xs text-muted">{m.achievements[nextTrophy.id as keyof typeof m.achievements].desc}</span>
              <ProgressBar value={achievementProgress(nextTrophy, progress)} className="mt-2 h-2" color="from-gold to-[#f59e0b]" />
            </span>
          </>
        ) : (
          <span className="flex items-center gap-3 font-semibold">
            <Sparkles className="h-6 w-6 text-gold" /> {m.app.allTrophies}
          </span>
        )}
      </Pressable>

      {/* Recent matches */}
      <SectionTitle
        action={
          progress.history.length > 0 && (
            <button type="button" onClick={() => push({ name: "history" })} className="text-sm font-semibold text-primary-soft">
              {m.app.seeAll}
            </button>
          )
        }
      >
        {m.app.recentTitle}
      </SectionTitle>
      {progress.history.length === 0 ? (
        <p className="rounded-3xl bg-white/5 p-5 text-center text-sm text-muted ring-1 ring-white/10">{m.app.noMatches}</p>
      ) : (
        <div className="space-y-2">
          {progress.history.slice(0, 3).map((h) => (
            <MatchRow key={h.id} match={h} when={timeAgo(h.at, now, m.app.ago)} />
          ))}
        </div>
      )}
    </div>
  );
}

/** Decorative shapes for the hero card. */
function HeroArt() {
  return (
    <svg aria-hidden="true" viewBox="0 0 200 200" className="absolute -right-6 -top-4 h-52 w-52 opacity-90">
      <circle cx="120" cy="80" r="70" fill="url(#ha)" opacity="0.35" />
      <path d="M128 30 92 104h26l-12 62 46-82h-28l10-54Z" fill="#fbbf24" stroke="#3b2600" strokeWidth="3" strokeLinejoin="round" />
      <circle cx="40" cy="150" r="10" fill="#06b6d4" opacity="0.8" />
      <circle cx="175" cy="160" r="6" fill="#f8fafc" opacity="0.6" />
      <defs>
        <radialGradient id="ha">
          <stop offset="0" stopColor="#f8fafc" />
          <stop offset="1" stopColor="#f8fafc" stopOpacity="0" />
        </radialGradient>
      </defs>
    </svg>
  );
}
