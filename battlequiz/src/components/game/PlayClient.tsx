"use client";

import { Loader2 } from "lucide-react";
import Link from "next/link";
import { useEffect } from "react";
import { LanguageSwitch, SoundToggle } from "@/components/layout/Controls";
import { Logo } from "@/components/layout/Logo";
import { useMessages } from "@/i18n";
import { useGame } from "@/stores/game";
import { Countdown } from "./Countdown";
import { ErrorPanel } from "./ErrorPanel";
import { GameScreen } from "./GameScreen";
import { ResultsScreen } from "./ResultsScreen";
import { SetupScreen } from "./SetupScreen";

/** Orchestrates the Quick Play flow: setup → countdown → questions → results. */
export function PlayClient() {
  const { m } = useMessages();
  const phase = useGame((s) => s.phase);
  const results = useGame((s) => s.results);
  const errorCode = useGame((s) => s.errorCode);
  const reset = useGame((s) => s.reset);
  const inMatch = ["question", "submitting", "feedback", "loadingNext", "loadingResults"].includes(phase);

  // Leaving the page abandons the client view; the server expires the match on its own.
  useEffect(() => () => reset(), [reset]);

  return (
    <div className="flex min-h-dvh flex-col">
      {!inMatch && (
        <header className="mx-auto flex w-full max-w-2xl items-center justify-between px-4 py-4">
          <Link href="/" aria-label={m.common.home}>
            <Logo />
          </Link>
          <div className="flex items-center gap-2">
            <LanguageSwitch />
            <SoundToggle />
          </div>
        </header>
      )}
      <main className={inMatch ? "flex-1 pt-4" : "flex-1 pt-2"}>
        {phase === "setup" && <SetupScreen />}
        {phase === "countdown" && <Countdown />}
        {phase === "starting" && (
          <div className="grid min-h-[60vh] place-items-center text-muted" role="status">
            <Loader2 className="h-8 w-8 animate-spin" aria-label={m.common.loading} />
          </div>
        )}
        {inMatch && <GameScreen />}
        {phase === "results" && results && <ResultsScreen results={results} />}
        {phase === "error" && <ErrorPanel code={errorCode} onRetry={reset} />}
      </main>
    </div>
  );
}
