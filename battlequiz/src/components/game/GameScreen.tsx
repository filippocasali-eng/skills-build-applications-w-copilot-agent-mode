"use client";

import { Flame, Loader2, X } from "lucide-react";
import { AnimatePresence, motion } from "motion/react";
import { useCallback, useEffect } from "react";
import { fmt, useMessages } from "@/i18n";
import { playSfx } from "@/lib/audio/sfx";
import { haptic } from "@/lib/native";
import { cn } from "@/lib/utils";
import { useGame } from "@/stores/game";
import { useSettings } from "@/stores/settings";
import { AnimatedNumber } from "./AnimatedNumber";
import { AnswerButton, type AnswerState } from "./AnswerButton";
import { CATEGORY_COLORS, CategoryIcon } from "./CategoryIcon";
import { ProgressSegments } from "./ProgressSegments";
import { TimerRing } from "./TimerRing";

const LETTERS = ["A", "B", "C", "D"];
/** How long answer feedback stays on screen before the next question. */
const FEEDBACK_MS = { correct: 1100, miss: 1800 };

const DIFFICULTY_STYLE = {
  easy: "text-success bg-success/10",
  medium: "text-secondary bg-secondary/10",
  hard: "text-gold bg-gold/10",
  expert: "text-error bg-error/10",
} as const;

/** Full-screen question view. Answers sit at the bottom, in thumb reach. */
export function GameScreen({ onQuit }: { onQuit: () => void }) {
  const { m } = useMessages();
  const soundOn = useSettings((s) => s.soundOn);
  const { phase, question, deadline, selected, feedback, score, streak, slots, answer, advance } = useGame();

  const answering = phase === "question";
  const showFeedback = !!feedback && (phase === "feedback" || phase === "loadingNext" || phase === "loadingResults");

  const select = useCallback(
    (i: number) => {
      if (!answering) return;
      playSfx("select", soundOn);
      void haptic("select");
      void answer(i);
    },
    [answering, answer, soundOn],
  );

  // Keyboard: 1–4 or A–D.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.metaKey || e.ctrlKey || e.altKey || e.key.length !== 1) return;
      const k = e.key.toLowerCase();
      const i = "1234".includes(k) ? "1234".indexOf(k) : "abcd".indexOf(k);
      if (i >= 0) select(i);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [select]);

  // Feedback sound/haptic + auto-advance.
  useEffect(() => {
    if (phase !== "feedback" || !feedback) return;
    playSfx(feedback.correct ? "correct" : "wrong", soundOn);
    void haptic(feedback.correct ? "success" : "error");
    const t = setTimeout(() => void advance(), feedback.correct ? FEEDBACK_MS.correct : FEEDBACK_MS.miss);
    return () => clearTimeout(t);
    // soundOn intentionally excluded: toggling sound must not replay feedback.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [phase, feedback, advance]);

  if (!question) return null;

  const stateFor = (i: number): AnswerState => {
    if (phase === "submitting") return i === selected ? "pending" : "dim";
    if (!showFeedback || !feedback) return "idle";
    if (i === feedback.correctIndex) return feedback.selectedIndex === i ? "correct" : "reveal";
    if (i === feedback.selectedIndex) return "wrong";
    return "dim";
  };

  const accent = CATEGORY_COLORS[question.category];

  return (
    <section className="safe-top safe-bottom flex h-full flex-col px-4" aria-labelledby="question-text">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-72 opacity-40" style={{ background: `radial-gradient(ellipse at 50% 0%, ${accent}, transparent 70%)` }} />

      {/* Top bar */}
      <div className="relative flex items-center gap-3 pt-2">
        <button type="button" onClick={onQuit} aria-label={m.game.quit} className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-white/10 text-text active:scale-95">
          <X className="h-5 w-5" />
        </button>
        <div className="flex-1">
          <ProgressSegments total={question.total} current={question.index} slots={slots} />
        </div>
        <span className="w-12 text-right font-display text-sm font-bold text-muted tabular-nums" data-testid="question-counter" aria-label={fmt(m.game.question, { n: question.index + 1, total: question.total })}>
          <span className="sr-only">{fmt(m.game.question, { n: question.index + 1, total: question.total })}</span>
          <span aria-hidden="true">
            {question.index + 1}/{question.total}
          </span>
        </span>
      </div>

      {/* Score · streak · timer */}
      <div className="relative mt-4 flex items-center justify-between">
        <div>
          <p className="text-[11px] font-bold uppercase tracking-widest text-muted">{m.game.score}</p>
          <AnimatedNumber value={score} className="font-display text-3xl font-black tabular-nums" />
        </div>
        <AnimatePresence>
          {streak >= 2 && (
            <motion.div
              key="streak"
              initial={{ scale: 0.5, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.5, opacity: 0 }}
              className="flex items-center gap-1.5 rounded-full bg-gold/15 px-3 py-1.5 text-gold ring-1 ring-gold/40"
              aria-label={`${m.game.streak} ${streak}`}
            >
              <Flame className="h-5 w-5 fill-current" aria-hidden="true" />
              <span className="font-display text-lg font-extrabold tabular-nums">×{streak}</span>
            </motion.div>
          )}
        </AnimatePresence>
        <TimerRing
          deadline={deadline}
          totalMs={question.timeLimitMs}
          running={answering}
          onExpire={() => void answer(null)}
          onSecond={(s) => {
            if (answering && s <= 3 && s > 0) {
              playSfx("tick", soundOn);
              void haptic("tap");
            }
          }}
          label={(s) => fmt(m.game.timeLeft, { s })}
        />
      </div>

      {/* Question */}
      <div className="relative flex flex-1 items-center py-4">
        <AnimatePresence mode="wait">
          <motion.div
            key={question.index}
            initial={{ opacity: 0, y: 24, scale: 0.97 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -16 }}
            transition={{ type: "spring", stiffness: 260, damping: 26 }}
            className="card-glass relative w-full overflow-hidden rounded-[2rem] p-6"
            style={{ boxShadow: `0 30px 60px -30px ${accent}88` }}
          >
            <div className="absolute inset-x-0 top-0 h-1" style={{ background: `linear-gradient(90deg, transparent, ${accent}, transparent)` }} />
            <div className="flex flex-wrap items-center gap-2 text-xs font-bold">
              <span className="inline-flex items-center gap-1.5 rounded-full px-2.5 py-1" style={{ background: `${accent}22`, color: accent }}>
                <CategoryIcon category={question.category} className="h-3.5 w-3.5" />
                {m.categories[question.category]}
              </span>
              <span className={cn("rounded-full px-2.5 py-1", DIFFICULTY_STYLE[question.difficulty])}>{m.difficulty[question.difficulty]}</span>
            </div>
            <h1 id="question-text" className="mt-4 font-display text-[1.45rem] font-bold leading-snug" data-testid="question-text">
              {question.text}
            </h1>
          </motion.div>
        </AnimatePresence>
      </div>

      {/* Feedback */}
      <div className="relative h-14" aria-live="polite">
        <AnimatePresence>
          {showFeedback && feedback && (
            <motion.div
              key={`fb-${feedback.questionIndex}`}
              initial={{ opacity: 0, y: 10, scale: 0.95 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              // No exit fade: a fast next answer must never show two feedback strips.
              exit={{ opacity: 0, transition: { duration: 0 } }}
              data-testid="feedback"
              className={cn(
                "absolute inset-x-0 top-0 flex h-12 items-center justify-between rounded-2xl px-4 font-display font-bold ring-1",
                feedback.correct ? "bg-success/15 text-success ring-success/40" : feedback.timedOut ? "bg-gold/10 text-gold ring-gold/40" : "bg-error/15 text-error ring-error/40",
              )}
            >
              <span>
                {feedback.correct ? m.game.correct : feedback.timedOut ? m.game.timeout : m.game.wrong}
                {feedback.correct && feedback.streak >= 2 && <span className="ml-2 text-gold">{fmt(m.game.streakMsg, { n: feedback.multiplier.toFixed(1) })}</span>}
              </span>
              {feedback.correct && (
                <motion.span initial={{ scale: 0.6 }} animate={{ scale: [0.6, 1.3, 1] }} className="text-xl text-gold-gradient tabular-nums">
                  +{feedback.points}
                </motion.span>
              )}
            </motion.div>
          )}
          {phase === "submitting" && (
            <motion.div key="sub" initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="flex h-12 items-center justify-center text-muted">
              <Loader2 className="h-5 w-5 animate-spin" aria-label={m.common.loading} />
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* Answers */}
      <div className="relative grid gap-2.5 pb-3" key={`answers-${question.index}`}>
        {question.options.map((opt, i) => (
          <AnswerButton
            key={i}
            index={i}
            text={opt}
            state={stateFor(i)}
            disabled={!answering}
            onSelect={select}
            ariaLabel={fmt(m.game.answerLabel, { letter: LETTERS[i], text: opt })}
          />
        ))}
      </div>
    </section>
  );
}
