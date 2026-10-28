"use client";

import { Loader2 } from "lucide-react";
import { useEffect } from "react";
import { create } from "zustand";
import { Countdown } from "@/components/game/Countdown";
import { ErrorPanel } from "@/components/game/ErrorPanel";
import { GameScreen } from "@/components/game/GameScreen";
import { ResultsScreen } from "@/components/game/ResultsScreen";
import { useMessages } from "@/i18n";
import { useGame, type GamePhase } from "@/stores/game";
import { useNav } from "@/stores/nav";
import type { CategorySelection, GameMode } from "@/types/game";
import { Pressable, Sheet } from "./primitives";

/** Phases during which leaving loses the match and must be confirmed. */
export const IN_MATCH_PHASES: readonly GamePhase[] = ["starting", "question", "submitting", "feedback", "loadingNext", "loadingResults"];

/** Quit-confirmation visibility, reachable from the Android back button handler. */
export const useMatchUi = create<{ quitOpen: boolean }>()(() => ({ quitOpen: false }));

export function MatchFlow({ mode, category }: { mode: GameMode; category: CategorySelection }) {
  const { m } = useMessages();
  const { phase, results, errorCode, beginCountdown, reset } = useGame();
  const { pop, replace, popToRoot } = useNav();
  const quitOpen = useMatchUi((s) => s.quitOpen);

  useEffect(() => {
    beginCountdown(mode, category);
    return () => reset();
  }, [mode, category, beginCountdown, reset]);

  const closeQuit = () => useMatchUi.setState({ quitOpen: false });
  const leave = () => {
    closeQuit();
    reset();
    pop();
  };
  const home = () => {
    reset();
    popToRoot("home");
  };
  const playAgain = () => {
    if (mode === "daily_challenge") replace({ name: "match", mode: "quick_play", category: "mixed" });
    else beginCountdown(mode, category);
  };

  return (
    <div className="relative h-full">
      {phase === "countdown" && <Countdown />}
      {phase === "starting" && (
        <div className="grid h-full place-items-center text-muted" role="status">
          <Loader2 className="h-8 w-8 animate-spin" aria-label={m.common.loading} />
        </div>
      )}
      {IN_MATCH_PHASES.includes(phase) && phase !== "starting" && <GameScreen onQuit={() => useMatchUi.setState({ quitOpen: true })} />}
      {phase === "results" && results && <ResultsScreen results={results} onPlayAgain={playAgain} onHome={home} />}
      {phase === "error" && (
        <div className="safe-top px-4">
          <ErrorPanel code={errorCode} onRetry={leave} />
        </div>
      )}

      <Sheet open={quitOpen} onClose={closeQuit} label={m.app.match.quitTitle}>
        <h2 className="font-display text-xl font-extrabold">{m.app.match.quitTitle}</h2>
        <p className="mt-2 text-sm text-muted">{m.app.match.quitText}</p>
        <div className="mt-6 grid gap-3 pb-4">
          <Pressable haptics="select" onClick={closeQuit} className="rounded-2xl bg-gradient-to-b from-[#8b5cf6] to-primary py-3.5 text-center font-bold">
            {m.app.match.stay}
          </Pressable>
          <Pressable onClick={leave} className="rounded-2xl bg-white/10 py-3.5 text-center font-bold text-error" data-testid="quit-confirm">
            {m.app.match.quit}
          </Pressable>
        </div>
      </Sheet>
    </div>
  );
}
