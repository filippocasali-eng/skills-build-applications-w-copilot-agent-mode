"use client";

import { animate, useReducedMotion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { useMessages } from "@/i18n";

/** Counts up/down to `value`. Jumps instantly when reduced motion is requested. */
export function AnimatedNumber({ value, duration = 0.6, className, from }: { value: number; duration?: number; className?: string; from?: number }) {
  const reduce = useReducedMotion();
  const { locale } = useMessages();
  const [display, setDisplay] = useState(from ?? value);
  const current = useRef(from ?? value);

  useEffect(() => {
    if (reduce) {
      current.current = value;
      return;
    }
    const controls = animate(current.current, value, {
      duration,
      ease: "easeOut",
      onUpdate: (v) => {
        current.current = v;
        setDisplay(Math.round(v));
      },
    });
    return () => controls.stop();
  }, [value, duration, reduce]);

  return <span className={className}>{(reduce ? value : display).toLocaleString(locale)}</span>;
}
