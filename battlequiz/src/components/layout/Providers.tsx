"use client";

import { MotionConfig } from "motion/react";
import { useEffect } from "react";
import { useSettings } from "@/stores/settings";

/** Applies per-device preferences (language, motion) to the document. */
export function Providers({ children }: { children: React.ReactNode }) {
  const locale = useSettings((s) => s.locale);
  const motion = useSettings((s) => s.motion);

  useEffect(() => {
    document.documentElement.lang = locale;
  }, [locale]);

  useEffect(() => {
    document.documentElement.dataset.motion = motion;
  }, [motion]);

  return (
    <MotionConfig reducedMotion={motion === "system" ? "user" : motion === "reduce" ? "always" : "never"}>{children}</MotionConfig>
  );
}
