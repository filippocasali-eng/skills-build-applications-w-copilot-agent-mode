"use client";

import { useEffect, useRef, useState } from "react";
import { cn } from "@/lib/utils";

interface TimerRingProps {
  /** performance.now() deadline, or null when paused. */
  deadline: number | null;
  totalMs: number;
  running: boolean;
  onExpire: () => void;
  /** Called once per whole second while running (for the countdown warning sound). */
  onSecond?: (secondsLeft: number) => void;
  label: (seconds: number) => string;
}

const R = 26;
const CIRC = 2 * Math.PI * R;

/** Countdown ring. Visual only: the server enforces the real time limit. */
export function TimerRing({ deadline, totalMs, running, onExpire, onSecond, label }: TimerRingProps) {
  const [remaining, setRemaining] = useState(totalMs);
  const expired = useRef(false);
  const lastSecond = useRef<number | null>(null);
  const cb = useRef({ onExpire, onSecond });
  useEffect(() => {
    cb.current = { onExpire, onSecond };
  });

  useEffect(() => {
    expired.current = false;
    lastSecond.current = null;
  }, [deadline]);

  useEffect(() => {
    if (!running || deadline === null) return;
    let raf = 0;
    const tick = () => {
      const left = Math.max(0, deadline - performance.now());
      setRemaining(left);
      const sec = Math.ceil(left / 1000);
      if (sec !== lastSecond.current) {
        lastSecond.current = sec;
        cb.current.onSecond?.(sec);
      }
      if (left <= 0) {
        if (!expired.current) {
          expired.current = true;
          cb.current.onExpire();
        }
        return;
      }
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [deadline, running]);

  const fraction = Math.max(0, Math.min(1, remaining / totalMs));
  const seconds = Math.ceil(remaining / 1000);
  const color = seconds <= 3 ? "#ef4444" : seconds <= 6 ? "#fbbf24" : "#06b6d4";

  return (
    <div
      role="timer"
      aria-live="off"
      aria-label={label(seconds)}
      className={cn("relative grid h-16 w-16 shrink-0 place-items-center", seconds <= 3 && running && "animate-pulse")}
    >
      <svg viewBox="0 0 64 64" className="absolute inset-0 -rotate-90">
        <circle cx="32" cy="32" r={R} fill="#0b1020" stroke="#2a3358" strokeWidth="6" />
        <circle
          cx="32"
          cy="32"
          r={R}
          fill="none"
          stroke={color}
          strokeWidth="6"
          strokeLinecap="round"
          strokeDasharray={CIRC}
          strokeDashoffset={CIRC * (1 - fraction)}
          style={{ filter: `drop-shadow(0 0 6px ${color})`, transition: "stroke 300ms" }}
        />
      </svg>
      <span className="relative font-display text-xl font-extrabold tabular-nums" style={{ color }}>
        {seconds}
      </span>
    </div>
  );
}
