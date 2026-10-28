"use client";

import { Check, ChevronDown, Crown, Flame, Home, RotateCcw, Share2, Target, Timer, Trophy, X, Zap } from "lucide-react";
import { motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { AchievementBadge } from "@/components/app/shared";
import { Pressable, ProgressBar } from "@/components/app/primitives";
import { levelFromXp } from "@/features/progression/levels";
import type { ApplyResult } from "@/features/progression/player";
import { fmt, useMessages } from "@/i18n";
import { playSfx } from "@/lib/audio/sfx";
import { haptic } from "@/lib/native";
import { cn } from "@/lib/utils";
import { usePlayer } from "@/stores/player";
import { useSettings } from "@/stores/settings";
import type { MatchResults } from "@/types/game";
import { AnimatedNumber } from "./AnimatedNumber";
import { Confetti } from "./Confetti";

type Grade = "legendary" | "great" | "good" | "keepGoing";

function gradeFor(correct: number, total: number): Grade {
  const r = total ? correct / total : 0;
  return r >= 0.9 ? "legendary" : r >= 0.7 ? "great" : r >= 0.4 ? "good" : "keepGoing";
}

interface ResultsScreenProps {
  results: MatchResults;
  onPlayAgain: () => void;
  onHome: () => void;
}

export function ResultsScreen({ results, onPlayAgain, onHome }: ResultsScreenProps) {
  const { m, locale } = useMessages();
  const soundOn = useSettings((s) => s.soundOn);
  const credit = usePlayer((s) => s.credit);
  const xp = usePlayer((s) => s.progress.xp);
  const [applied, setApplied] = useState<ApplyResult | null>(null);
  const [shareMsg, setShareMsg] = useState<string | null>(null);
  const [reviewOpen, setReviewOpen] = useState(false);
  const once = useRef(false);

  // Credit progression exactly once per match (idempotent across re-renders and reloads).
  useEffect(() => {
    if (once.current) return;
    once.current = true;
    setApplied(credit(results));
  }, [credit, results]);

  const grade = gradeFor(results.correctCount, results.totalQuestions);
  const newBest = !!applied && !applied.alreadyCredited && results.score > applied.previousBest && results.score > 0;
  const leveledUp = !!applied && applied.levelAfter > applied.levelBefore;
  const celebrate = grade === "legendary" || grade === "great" || newBest || leveledUp;
  const daily = results.mode === "daily_challenge";

  useEffect(() => {
    if (!applied) return;
    if (celebrate) {
      playSfx("victory", soundOn);
      void haptic("success");
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [applied]);

  const level = levelFromXp(xp);

  const share = async () => {
    const text = fmt(m.results.shareText, { score: results.score, correct: results.correctCount, total: results.totalQuestions });
    const grid = results.review.map((r) => (r.correct ? "🟩" : r.timedOut ? "🟨" : "🟥")).join("");
    const payload = `${text}\n${grid}`;
    try {
      if (navigator.share) await navigator.share({ title: "BattleQuiz", text: payload });
      else {
        await navigator.clipboard.writeText(payload);
        setShareMsg(m.results.shared);
      }
    } catch {
      // Share sheet cancelled or clipboard unavailable.
    }
  };

  const stats = [
    { icon: Check, label: m.results.correct, value: `${results.correctCount}/${results.totalQuestions}`, color: "text-success" },
    { icon: Target, label: m.results.accuracy, value: `${Math.round(results.accuracy * 100)}%`, color: "text-secondary" },
    { icon: Flame, label: m.results.bestStreak, value: `${results.bestStreak}`, color: "text-gold" },
    { icon: Timer, label: m.results.avgTime, value: `${(results.averageResponseMs / 1000).toFixed(1)}s`, color: "text-primary-soft" },
  ];

  return (
    <section className="flex h-full flex-col" aria-labelledby="results-title">
      <Confetti fire={!!applied && celebrate} />
      <div className="no-scrollbar flex-1 overflow-y-auto">
        <div className="safe-top px-4 pb-6">
          <div className="flex items-center justify-between pt-2">
            <Pressable onClick={onHome} aria-label={m.app.results.home} className="grid h-10 w-10 place-items-center rounded-full bg-white/10">
              <X className="h-5 w-5" />
            </Pressable>
            <p className="text-xs font-bold uppercase tracking-[0.25em] text-muted">{daily ? m.app.daily.title : m.results.title}</p>
            <Pressable onClick={share} aria-label={m.results.share} className="grid h-10 w-10 place-items-center rounded-full bg-white/10">
              <Share2 className="h-5 w-5" />
            </Pressable>
          </div>

          <div className="relative mt-4 text-center">
            <div className="pointer-events-none absolute -top-10 left-1/2 h-56 w-72 -translate-x-1/2 rounded-full bg-primary/40 blur-3xl" />
            <motion.div initial={{ rotate: -15, scale: 0.3 }} animate={{ rotate: 0, scale: 1 }} transition={{ type: "spring", stiffness: 220, damping: 14 }} className="relative mx-auto grid h-24 w-24 place-items-center rounded-[1.75rem] bg-gradient-to-br from-[#fde68a] via-gold to-[#f59e0b] shadow-[0_0_60px_-8px_rgb(251_191_36/0.9)]">
              {grade === "legendary" ? <Crown className="h-12 w-12 text-[#3b2600]" /> : <Trophy className="h-12 w-12 text-[#3b2600]" />}
            </motion.div>
            <h1 id="results-title" className="relative mt-4 font-display text-3xl font-black">
              {m.results.grades[grade]}
            </h1>
            <AnimatedNumber value={results.score} from={0} duration={1.4} className="relative mt-2 block font-display text-7xl font-black tabular-nums text-gold-gradient" />
            <p className="relative text-sm font-semibold text-muted">{m.results.finalScore}</p>
            <div className="relative mt-2 h-7" data-testid="final-score" data-score={results.score}>
              {newBest && (
                <motion.span initial={{ scale: 0 }} animate={{ scale: 1 }} transition={{ delay: 1.2, type: "spring" }} className="inline-flex items-center gap-1.5 rounded-full bg-gold/15 px-3 py-1 text-sm font-bold text-gold ring-1 ring-gold/40">
                  <Crown className="h-4 w-4" /> {m.results.newBest}
                </motion.span>
              )}
            </div>
          </div>

          <div className="mt-4 grid grid-cols-4 gap-2">
            {stats.map(({ icon: Icon, label, value, color }, i) => (
              <motion.div key={label} initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.3 + i * 0.07 }} className="rounded-2xl bg-surface px-1 py-3 text-center ring-1 ring-white/10">
                <Icon className={cn("mx-auto h-5 w-5", color)} aria-hidden="true" />
                <p className="mt-1 font-display text-lg font-extrabold tabular-nums">{value}</p>
                <p className="text-[10px] leading-tight text-muted">{label}</p>
              </motion.div>
            ))}
          </div>

          {/* XP & level */}
          <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.6 }} className={cn("mt-3 rounded-3xl p-4 ring-1", leveledUp ? "bg-primary/20 ring-primary/50" : "bg-surface ring-white/10")}>
            <div className="flex items-center justify-between">
              <span className="flex items-center gap-2 font-display font-bold">
                <Zap className="h-5 w-5 text-secondary" />
                {leveledUp ? fmt(m.app.results.levelUp, { level: level.level }) : fmt(m.app.level, { level: level.level })}
              </span>
              <span className="font-display font-extrabold text-secondary">{fmt(m.results.xpEarned, { xp: results.xpEarned })}</span>
            </div>
            <ProgressBar value={level.progress} className="mt-3" />
            <p className="mt-2 text-xs text-muted">{fmt(m.results.xpToNext, { xp: level.xpForNext - level.xpIntoLevel, level: level.level + 1 })}</p>
          </motion.div>

          {/* Unlocked trophies */}
          {applied && applied.unlocked.length > 0 && (
            <div className="mt-3 space-y-2">
              {applied.unlocked.map((a, i) => (
                <motion.div key={a.id} initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }} transition={{ delay: 0.9 + i * 0.15, type: "spring" }} className="flex items-center gap-3 rounded-3xl bg-gold/10 p-3 ring-1 ring-gold/40" data-testid="unlocked-trophy">
                  <AchievementBadge icon={a.icon} unlocked size={44} />
                  <div className="flex-1">
                    <p className="text-[11px] font-bold uppercase tracking-wider text-gold">{m.app.results.unlocked}</p>
                    <p className="font-bold">{m.achievements[a.id as keyof typeof m.achievements].name}</p>
                  </div>
                  <span className="text-sm font-bold text-secondary">+{a.xpReward} XP</span>
                </motion.div>
              ))}
            </div>
          )}

          {daily && <p className="mt-3 text-center text-xs text-muted">{m.app.daily.unranked}</p>}
          <p className="mt-1 h-5 text-center text-sm text-success" role="status">{shareMsg}</p>

          {/* Review */}
          <div className="mt-2 rounded-3xl bg-surface ring-1 ring-white/10">
            <button type="button" onClick={() => setReviewOpen((v) => !v)} aria-expanded={reviewOpen} className="flex w-full items-center justify-between px-5 py-4 font-display font-bold">
              {m.results.review}
              <ChevronDown className={cn("h-5 w-5 transition-transform", reviewOpen && "rotate-180")} />
            </button>
            {reviewOpen && (
              <ol className="space-y-2.5 px-4 pb-4">
                {results.review.map((r) => (
                  <li key={r.index} className="rounded-2xl bg-white/5 p-3.5">
                    <div className="flex items-start gap-3">
                      <span className={cn("mt-0.5 grid h-6 w-6 shrink-0 place-items-center rounded-full", r.correct ? "bg-success/20 text-success" : r.timedOut ? "bg-gold/20 text-gold" : "bg-error/20 text-error")}>
                        {r.correct ? <Check className="h-4 w-4" /> : r.timedOut ? <Timer className="h-4 w-4" /> : <X className="h-4 w-4" />}
                      </span>
                      <div className="min-w-0 flex-1">
                        <p className="text-sm font-semibold">{r.text}</p>
                        {!r.correct && (
                          <p className="mt-1 text-xs text-error">
                            {m.results.yourAnswer}: {r.selectedIndex !== null ? r.options[r.selectedIndex] : m.results.noAnswer}
                          </p>
                        )}
                        <p className="mt-1 text-xs text-success">
                          {m.results.correctAnswer}: {r.options[r.correctIndex]}
                        </p>
                        <p className="mt-1 text-xs text-muted">{r.explanation}</p>
                      </div>
                      <span className="text-sm font-bold tabular-nums text-gold">+{r.points.toLocaleString(locale)}</span>
                    </div>
                  </li>
                ))}
              </ol>
            )}
          </div>
        </div>
      </div>

      {/* Sticky actions */}
      <div className="safe-bottom border-t border-white/5 bg-bg/90 px-4 pt-3 backdrop-blur-xl">
        <div className="grid grid-cols-[auto_1fr] gap-3 pb-3">
          <Pressable onClick={onHome} aria-label={m.app.results.home} className="grid h-14 w-14 place-items-center rounded-2xl bg-white/10">
            <Home className="h-6 w-6" />
          </Pressable>
          <Pressable
            haptics="select"
            data-testid="play-again"
            onClick={onPlayAgain}
            className="flex h-14 items-center justify-center gap-2 rounded-2xl bg-gradient-to-b from-[#8b5cf6] to-primary font-display text-lg font-extrabold shadow-[0_12px_30px_-10px_rgb(124_58_237/0.9)]"
          >
            <RotateCcw className="h-5 w-5" /> {daily ? m.app.quickPlay.title : m.results.playAgain}
          </Pressable>
        </div>
      </div>
    </section>
  );
}
