"use client";

import { Check, ChevronDown, Crown, Flame, Home, RotateCcw, Share2, Swords, Target, Timer, Trophy, UserPlus, X } from "lucide-react";
import { motion } from "motion/react";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { levelFromXp } from "@/features/progression/levels";
import { fmt, useMessages } from "@/i18n";
import { playSfx } from "@/lib/audio/sfx";
import { cn } from "@/lib/utils";
import { useGame } from "@/stores/game";
import { useGuestProfile } from "@/stores/guest-profile";
import { useSettings } from "@/stores/settings";
import type { MatchResults } from "@/types/game";
import { AnimatedNumber } from "./AnimatedNumber";
import { Confetti } from "./Confetti";

type Grade = "legendary" | "great" | "good" | "keepGoing";

function gradeFor(correct: number, total: number): Grade {
  const r = total ? correct / total : 0;
  return r >= 0.9 ? "legendary" : r >= 0.7 ? "great" : r >= 0.4 ? "good" : "keepGoing";
}

export function ResultsScreen({ results }: { results: MatchResults }) {
  const { m, locale } = useMessages();
  const soundOn = useSettings((s) => s.soundOn);
  const beginCountdown = useGame((s) => s.beginCountdown);
  const credit = useGuestProfile((s) => s.credit);
  const totalXp = useGuestProfile((s) => s.xp);
  const matchesPlayed = useGuestProfile((s) => s.matchesPlayed);
  const [credited, setCredited] = useState<{ previousBest: number; previousXp: number } | null>(null);
  const [shareMsg, setShareMsg] = useState<string | null>(null);
  const [reviewOpen, setReviewOpen] = useState(false);
  const once = useRef(false);

  // Credit temporary guest XP exactly once per match (idempotent across reloads).
  useEffect(() => {
    if (once.current) return;
    once.current = true;
    setCredited(credit(results));
  }, [credit, results]);

  const grade = gradeFor(results.correctCount, results.totalQuestions);
  const newBest = credited !== null && results.score > credited.previousBest && results.score > 0;
  const celebrate = grade === "legendary" || grade === "great" || newBest;

  useEffect(() => {
    if (credited && celebrate) playSfx("victory", soundOn);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [credited]);

  const level = levelFromXp(totalXp);
  const prevLevel = levelFromXp(credited?.previousXp ?? totalXp);

  const share = async () => {
    const text = fmt(m.results.shareText, { score: results.score, correct: results.correctCount, total: results.totalQuestions });
    const grid = results.review.map((r) => (r.correct ? "🟩" : r.timedOut ? "🟨" : "🟥")).join("");
    const payload = `${text}\n${grid}\n${window.location.origin}`;
    try {
      if (navigator.share) await navigator.share({ title: "BattleQuiz", text: payload });
      else {
        await navigator.clipboard.writeText(payload);
        setShareMsg(m.results.shared);
      }
    } catch {
      // User cancelled the share sheet or clipboard is unavailable: nothing to do.
    }
  };

  const stats = [
    { icon: Check, label: m.results.correct, value: `${results.correctCount}/${results.totalQuestions}`, color: "text-success" },
    { icon: Target, label: m.results.accuracy, value: `${Math.round(results.accuracy * 100)}%`, color: "text-secondary" },
    { icon: Flame, label: m.results.bestStreak, value: `${results.bestStreak}`, color: "text-gold" },
    { icon: Timer, label: m.results.avgTime, value: `${(results.averageResponseMs / 1000).toFixed(1)}s`, color: "text-primary-soft" },
  ];

  return (
    <section className="mx-auto w-full max-w-2xl px-4 pb-14" aria-labelledby="results-title">
      <Confetti fire={credited !== null && celebrate} />

      <motion.div
        initial={{ opacity: 0, y: 20, scale: 0.96 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        transition={{ type: "spring", stiffness: 200, damping: 20 }}
        className="card-glass relative overflow-hidden rounded-[2rem] p-6 text-center sm:p-8"
      >
        <div className="pointer-events-none absolute -top-24 left-1/2 h-48 w-72 -translate-x-1/2 rounded-full bg-primary/40 blur-3xl" />
        <motion.div initial={{ rotate: -12, scale: 0.4 }} animate={{ rotate: 0, scale: 1 }} transition={{ type: "spring", delay: 0.15 }} className="relative mx-auto grid h-20 w-20 place-items-center rounded-3xl bg-gradient-to-br from-gold to-[#f59e0b] shadow-[0_0_40px_-6px_rgb(251_191_36/0.8)]">
          {grade === "legendary" ? <Crown className="h-10 w-10 text-[#3b2600]" /> : <Trophy className="h-10 w-10 text-[#3b2600]" />}
        </motion.div>
        <p className="relative mt-4 text-xs font-bold uppercase tracking-[0.3em] text-muted">{m.results.title}</p>
        <h1 id="results-title" className="relative mt-1 font-display text-3xl font-extrabold sm:text-4xl">
          {m.results.grades[grade]}
        </h1>

        <p className="relative mt-5 text-sm text-muted">{m.results.finalScore}</p>
        <AnimatedNumber value={results.score} from={0} duration={1.4} className="relative block font-display text-6xl font-black tabular-nums text-gold-gradient sm:text-7xl" />
        <div className="relative mt-2 h-7" data-testid="final-score" data-score={results.score}>
          {newBest ? (
            <motion.span initial={{ scale: 0 }} animate={{ scale: 1 }} transition={{ delay: 1.2, type: "spring" }} className="inline-flex items-center gap-1.5 rounded-full bg-gold/15 px-3 py-1 text-sm font-bold text-gold ring-1 ring-gold/40">
              <Crown className="h-4 w-4" /> {m.results.newBest}
            </motion.span>
          ) : (
            credited && credited.previousBest > 0 && <span className="text-sm text-muted">{fmt(m.results.personalBest, { score: credited.previousBest.toLocaleString(locale) })}</span>
          )}
        </div>

        <div className="relative mt-6 grid grid-cols-2 gap-2.5 sm:grid-cols-4">
          {stats.map(({ icon: Icon, label, value, color }, i) => (
            <motion.div key={label} initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.3 + i * 0.08 }} className="rounded-2xl bg-white/5 p-3 ring-1 ring-white/10">
              <Icon className={cn("mx-auto h-5 w-5", color)} aria-hidden="true" />
              <p className="mt-1 font-display text-xl font-extrabold tabular-nums">{value}</p>
              <p className="text-xs text-muted">{label}</p>
            </motion.div>
          ))}
        </div>

        {/* XP and level (temporary guest progression) */}
        <div className="relative mt-6 rounded-2xl bg-white/5 p-4 text-left ring-1 ring-white/10">
          <div className="flex items-center justify-between">
            <span className="font-display font-bold">
              {fmt(m.results.level, { level: level.level })}
              {level.level > prevLevel.level && <span className="ml-2 text-gold">▲</span>}
            </span>
            <span className="font-display font-extrabold text-secondary">{fmt(m.results.xpEarned, { xp: results.xpEarned })}</span>
          </div>
          <div className="mt-2 h-3 overflow-hidden rounded-full bg-white/10">
            <motion.div initial={{ width: `${prevLevel.level === level.level ? prevLevel.progress * 100 : 0}%` }} animate={{ width: `${level.progress * 100}%` }} transition={{ duration: 1.2, delay: 0.6 }} className="h-full rounded-full bg-gradient-to-r from-primary to-secondary" />
          </div>
          <p className="mt-2 text-xs text-muted">
            {fmt(m.results.xpToNext, { xp: level.xpForNext - level.xpIntoLevel, level: level.level + 1 })} · {m.results.guestNote}
          </p>
        </div>

        <div className="relative mt-6 flex flex-col gap-2.5 sm:flex-row sm:justify-center">
          <Button size="lg" data-testid="play-again" onClick={beginCountdown}>
            <RotateCcw className="h-5 w-5" /> {m.results.playAgain}
          </Button>
          <Button size="lg" variant="secondary" onClick={share}>
            <Share2 className="h-5 w-5" /> {m.results.share}
          </Button>
          <Button size="lg" variant="ghost" disabled title={m.common.comingSoon}>
            <Swords className="h-5 w-5" /> {m.results.challenge}
            <span className="rounded-md bg-white/10 px-1.5 py-0.5 text-[10px] uppercase">{m.common.comingSoon}</span>
          </Button>
        </div>
        <p className="mt-2 h-5 text-sm text-success" role="status">{shareMsg}</p>
      </motion.div>

      {matchesPlayed <= 1 && (
        <div className="card-glass mt-4 flex items-start gap-3 rounded-2xl p-4">
          <UserPlus className="mt-0.5 h-6 w-6 shrink-0 text-primary-soft" aria-hidden="true" />
          <div>
            <p className="font-bold">{m.results.accountTitle}</p>
            <p className="text-sm text-muted">{m.results.accountText}</p>
          </div>
        </div>
      )}

      {/* Review */}
      <div className="card-glass mt-4 rounded-2xl">
        <button type="button" onClick={() => setReviewOpen((v) => !v)} aria-expanded={reviewOpen} className="flex w-full items-center justify-between px-5 py-4 font-display font-bold">
          {m.results.review}
          <ChevronDown className={cn("h-5 w-5 transition-transform", reviewOpen && "rotate-180")} />
        </button>
        {reviewOpen && (
          <ol className="space-y-3 px-5 pb-5">
            {results.review.map((r) => (
              <li key={r.index} className="rounded-xl bg-white/5 p-4 ring-1 ring-white/10">
                <div className="flex items-start gap-3">
                  <span className={cn("mt-0.5 grid h-6 w-6 shrink-0 place-items-center rounded-full", r.correct ? "bg-success/20 text-success" : r.timedOut ? "bg-gold/20 text-gold" : "bg-error/20 text-error")}>
                    {r.correct ? <Check className="h-4 w-4" /> : r.timedOut ? <Timer className="h-4 w-4" /> : <X className="h-4 w-4" />}
                  </span>
                  <div className="flex-1">
                    <p className="font-semibold">{r.index + 1}. {r.text}</p>
                    {!r.correct && (
                      <p className="mt-1 text-sm text-error">
                        {m.results.yourAnswer}: {r.selectedIndex !== null ? r.options[r.selectedIndex] : m.results.noAnswer}
                      </p>
                    )}
                    <p className="mt-1 text-sm text-success">{m.results.correctAnswer}: {r.options[r.correctIndex]}</p>
                    <p className="mt-1 text-sm text-muted">{r.explanation}</p>
                  </div>
                  <span className="font-display font-bold tabular-nums text-gold">+{r.points}</span>
                </div>
              </li>
            ))}
          </ol>
        )}
      </div>

      <div className="mt-6 text-center">
        <Link href="/" className="inline-flex items-center gap-2 text-sm text-muted hover:text-text">
          <Home className="h-4 w-4" /> {m.common.home}
        </Link>
      </div>
    </section>
  );
}
