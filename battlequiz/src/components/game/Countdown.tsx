"use client";

import { AnimatePresence, motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { useMessages } from "@/i18n";
import { playSfx } from "@/lib/audio/sfx";
import { useGame } from "@/stores/game";
import { useSettings } from "@/stores/settings";

/** 3-2-1 before the match. The match (and its server timer) is created only when it ends. */
export function Countdown() {
  const { m, locale } = useMessages();
  const soundOn = useSettings((s) => s.soundOn);
  const start = useGame((s) => s.start);
  const [n, setN] = useState(3);
  // Guards against double invocation (React Strict Mode) creating two matches.
  const started = useRef(false);

  useEffect(() => {
    if (n < 0) {
      if (!started.current) {
        started.current = true;
        void start(locale);
      }
      return;
    }
    playSfx(n === 0 ? "start" : "tick", soundOn);
    const t = setTimeout(() => setN((x) => x - 1), n === 0 ? 450 : 650);
    return () => clearTimeout(t);
  }, [n, start, locale, soundOn]);

  return (
    <div className="grid h-full place-items-center" role="status" aria-live="assertive">
      <AnimatePresence mode="popLayout">
        {n >= 0 && (
          <motion.div
            key={n}
            initial={{ scale: 0.4, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            exit={{ scale: 1.8, opacity: 0 }}
            transition={{ type: "spring", stiffness: 300, damping: 18 }}
            className="font-display text-8xl font-black sm:text-9xl"
          >
            <span className={n === 0 ? "text-gold-gradient" : "text-gradient"}>{n === 0 ? m.countdown.go : n}</span>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
