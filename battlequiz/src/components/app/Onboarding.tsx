"use client";

import { Flame, Timer, Trophy } from "lucide-react";
import { AnimatePresence, motion } from "motion/react";
import { useState } from "react";
import { LogoMark } from "@/components/layout/Logo";
import { useMessages } from "@/i18n";
import { haptic } from "@/lib/native";
import { cn } from "@/lib/utils";
import { AVATAR_COLORS, usePlayer } from "@/stores/player";
import { useSettings } from "@/stores/settings";
import { Avatar, Pressable, Segmented } from "./primitives";

const ART = [
  () => <LogoMark className="h-32 w-32 drop-shadow-[0_0_40px_rgb(124_58_237/0.8)]" />,
  () => (
    <div className="relative grid h-32 w-32 place-items-center rounded-full bg-secondary/15 ring-8 ring-secondary/30">
      <Timer className="h-16 w-16 text-secondary" />
    </div>
  ),
  () => (
    <div className="flex items-end gap-3">
      <Flame className="h-16 w-16 fill-gold/40 text-gold" />
      <Trophy className="h-24 w-24 text-gold" />
    </div>
  ),
];

/** First-launch walkthrough + nickname. Skippable at any time. */
export function Onboarding() {
  const { m, locale } = useMessages();
  const setLocale = useSettings((s) => s.setLocale);
  const { setProfile, completeOnboarding, avatarColor } = usePlayer();
  const [step, setStep] = useState(0);
  const [name, setName] = useState("");
  const slides = m.app.onboarding.slides;
  const isName = step === slides.length;

  const finish = () => {
    void haptic("success");
    if (name.trim()) setProfile({ nickname: name.trim() });
    completeOnboarding();
  };

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="safe-top safe-bottom fixed inset-0 z-[70] flex flex-col bg-bg" data-testid="onboarding">
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_50%_30%,rgb(124_58_237/0.35),transparent_60%)]" />
      <div className="relative flex items-center justify-between px-5 pt-3">
        <Segmented label={m.common.language} value={locale} onChange={setLocale} options={[{ value: "it", label: "IT" }, { value: "en", label: "EN" }]} />
        <button type="button" onClick={finish} className="px-2 py-2 text-sm font-semibold text-muted" data-testid="onboarding-skip">
          {m.app.onboarding.skip}
        </button>
      </div>

      <div className="relative flex flex-1 flex-col items-center justify-center px-8 text-center">
        <AnimatePresence mode="wait">
          <motion.div key={step} initial={{ opacity: 0, x: 40 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -40 }} transition={{ duration: 0.25 }} className="flex w-full flex-col items-center">
            {isName ? (
              <>
                <Avatar name={name || "?"} color={avatarColor} size={96} />
                <h1 className="mt-8 font-display text-3xl font-black">{m.app.onboarding.nameTitle}</h1>
                <input
                  autoFocus
                  value={name}
                  maxLength={20}
                  onChange={(e) => setName(e.target.value)}
                  onKeyDown={(e) => e.key === "Enter" && finish()}
                  placeholder={m.app.onboarding.namePlaceholder}
                  className="mt-6 w-full max-w-xs rounded-2xl bg-white/5 px-4 py-4 text-center text-lg font-bold outline-none ring-2 ring-white/10 focus:ring-primary"
                  data-testid="onboarding-name"
                />
                <div className="mt-5 flex gap-2.5">
                  {AVATAR_COLORS.slice(0, 6).map((c) => (
                    <button key={c} type="button" aria-label={c} onClick={() => setProfile({ avatarColor: c })} className={cn("h-8 w-8 rounded-full", c === avatarColor && "ring-2 ring-white ring-offset-2 ring-offset-bg")} style={{ background: c }} />
                  ))}
                </div>
                <p className="mt-4 text-sm text-muted">{m.app.onboarding.nameHint}</p>
              </>
            ) : (
              <>
                <div className="grid h-48 place-items-center">{ART[step]()}</div>
                <h1 className="mt-8 font-display text-3xl font-black leading-tight">{slides[step].title}</h1>
                <p className="mt-3 max-w-xs text-muted">{slides[step].text}</p>
              </>
            )}
          </motion.div>
        </AnimatePresence>
      </div>

      <div className="relative px-6 pb-6">
        <div className="mb-6 flex justify-center gap-2">
          {[...slides, null].map((_, i) => (
            <span key={i} className={cn("h-2 rounded-full transition-all", i === step ? "w-7 bg-primary" : "w-2 bg-white/20")} />
          ))}
        </div>
        <Pressable
          haptics="select"
          data-testid="onboarding-next"
          onClick={() => (isName ? finish() : setStep((s) => s + 1))}
          className="w-full rounded-2xl bg-gradient-to-b from-[#8b5cf6] to-primary py-4 text-center font-display text-lg font-extrabold shadow-[0_12px_30px_-10px_rgb(124_58_237/0.9)]"
        >
          {isName ? m.app.onboarding.start : m.app.onboarding.next}
        </Pressable>
      </div>
    </motion.div>
  );
}
