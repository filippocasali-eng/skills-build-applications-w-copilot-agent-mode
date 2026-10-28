"use client";

import { CalendarCheck, CalendarDays, Lock, Radio, Swords, Zap, type LucideIcon } from "lucide-react";
import { motion } from "motion/react";
import { CATEGORY_COLORS, CategoryIcon } from "@/components/game/CategoryIcon";
import { utcDay } from "@/features/gameplay/service-time";
import { fmt, useMessages } from "@/i18n";
import { cn } from "@/lib/utils";
import { useNav } from "@/stores/nav";
import { usePlayer } from "@/stores/player";
import { QUESTION_CATEGORIES } from "@/types/game";
import { Pressable, SectionTitle } from "./primitives";
import { useNow } from "./shared";

function ModeCard({ icon: Icon, title, subtitle, gradient, onClick, locked, badge, testId }: { icon: LucideIcon; title: string; subtitle: string; gradient: string; onClick?: () => void; locked?: boolean; badge?: string; testId?: string }) {
  return (
    <Pressable
      haptics={locked ? false : "select"}
      disabled={locked}
      onClick={onClick}
      data-testid={testId}
      className={cn("relative flex w-full items-center gap-4 overflow-hidden rounded-3xl p-4 ring-1", locked ? "bg-surface/70 ring-white/5" : `bg-gradient-to-br ${gradient} ring-white/15`)}
    >
      <span className={cn("grid h-14 w-14 shrink-0 place-items-center rounded-2xl", locked ? "bg-white/5 text-muted" : "bg-white/15")}>
        <Icon className="h-7 w-7" />
      </span>
      <span className="min-w-0 flex-1">
        <span className={cn("block font-display text-lg font-extrabold", locked && "text-muted")}>{title}</span>
        <span className="block text-sm text-white/70">{subtitle}</span>
      </span>
      {locked ? (
        <span className="flex items-center gap-1 rounded-full bg-white/5 px-2.5 py-1 text-[11px] font-bold uppercase text-muted">
          <Lock className="h-3 w-3" /> {badge}
        </span>
      ) : (
        badge && <span className="rounded-full bg-white/15 px-2.5 py-1 text-[11px] font-bold uppercase">{badge}</span>
      )}
    </Pressable>
  );
}

export function PlayScreen() {
  const { m } = useMessages();
  const push = useNav((s) => s.push);
  const daily = usePlayer((s) => s.progress.daily);
  const now = useNow();
  const dailyDone = daily[utcDay(now)];

  return (
    <div className="px-4 pb-6">
      <h1 className="pt-3 font-display text-3xl font-black">{m.app.tabs.play}</h1>
      <SectionTitle>{m.app.modesTitle}</SectionTitle>
      <div className="space-y-3">
        <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }}>
          <ModeCard testId="mode-quick" icon={Zap} title={m.app.quickPlay.title} subtitle={m.app.quickPlay.subtitle} gradient="from-[#8b5cf6] to-[#4c1d95]" onClick={() => push({ name: "match", mode: "quick_play", category: "mixed" })} />
        </motion.div>
        <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.05 }}>
          <ModeCard
            testId="mode-daily"
            icon={dailyDone ? CalendarCheck : CalendarDays}
            title={m.app.daily.title}
            subtitle={dailyDone ? fmt(m.app.daily.result, { score: dailyDone.score.toLocaleString(), correct: dailyDone.correct, total: dailyDone.total }) : m.app.daily.subtitle}
            gradient="from-[#0e7490] to-[#164e63]"
            badge={dailyDone ? m.app.daily.done : undefined}
            locked={!!dailyDone}
            onClick={() => push({ name: "match", mode: "daily_challenge", category: "mixed" })}
          />
        </motion.div>
        <ModeCard icon={Swords} title={m.app.modes.friend.title} subtitle={m.app.modes.friend.subtitle} gradient="" locked badge={m.app.soon} />
        <ModeCard icon={Radio} title={m.app.modes.live.title} subtitle={m.app.modes.live.subtitle} gradient="" locked badge={m.app.soon} />
      </div>

      <SectionTitle>{m.app.practiceTitle}</SectionTitle>
      <p className="-mt-2 mb-3 px-1 text-sm text-muted">{m.app.practiceHint}</p>
      <div className="grid grid-cols-2 gap-3">
        {QUESTION_CATEGORIES.map((c, i) => (
          <motion.div key={c} initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} transition={{ delay: 0.02 * i }}>
            <Pressable
              data-testid={`category-${c}`}
              onClick={() => push({ name: "match", mode: "quick_play", category: c })}
              className="relative flex h-28 w-full flex-col justify-between overflow-hidden rounded-3xl p-4 ring-1 ring-white/10"
              style={{ background: `linear-gradient(145deg, ${CATEGORY_COLORS[c]}40, #151b30 70%)` }}
            >
              <CategoryIcon category={c} className="absolute -bottom-3 -right-3 h-20 w-20 opacity-15" />
              <span className="grid h-10 w-10 place-items-center rounded-xl" style={{ background: `${CATEGORY_COLORS[c]}33`, color: CATEGORY_COLORS[c] }}>
                <CategoryIcon category={c} className="h-5 w-5" />
              </span>
              <span className="font-bold leading-tight">{m.categories[c]}</span>
            </Pressable>
          </motion.div>
        ))}
      </div>
    </div>
  );
}
