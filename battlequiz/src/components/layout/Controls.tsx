"use client";

import { Volume2, VolumeX } from "lucide-react";
import { useMessages } from "@/i18n";
import { cn } from "@/lib/utils";
import { useSettings } from "@/stores/settings";
import { LOCALES } from "@/types/game";

export function LanguageSwitch({ className }: { className?: string }) {
  const { m, locale } = useMessages();
  const setLocale = useSettings((s) => s.setLocale);
  return (
    <div role="group" aria-label={m.common.language} className={cn("flex rounded-xl bg-white/5 p-1 ring-1 ring-white/10", className)}>
      {LOCALES.map((l) => (
        <button
          key={l}
          type="button"
          onClick={() => setLocale(l)}
          aria-pressed={locale === l}
          className={cn(
            "rounded-lg px-2.5 py-1 text-xs font-bold uppercase tracking-wide transition-colors",
            locale === l ? "bg-primary text-white" : "text-muted hover:text-text",
          )}
        >
          {l}
        </button>
      ))}
    </div>
  );
}

export function SoundToggle({ className }: { className?: string }) {
  const { m } = useMessages();
  const soundOn = useSettings((s) => s.soundOn);
  const toggle = useSettings((s) => s.toggleSound);
  const label = soundOn ? m.common.soundOn : m.common.soundOff;
  return (
    <button
      type="button"
      onClick={toggle}
      aria-pressed={soundOn}
      aria-label={label}
      title={label}
      className={cn("grid h-9 w-9 place-items-center rounded-xl bg-white/5 text-muted ring-1 ring-white/10 transition-colors hover:text-text", className)}
    >
      {soundOn ? <Volume2 className="h-4 w-4" /> : <VolumeX className="h-4 w-4" />}
    </button>
  );
}
