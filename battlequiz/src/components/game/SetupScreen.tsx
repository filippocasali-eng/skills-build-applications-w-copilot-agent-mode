"use client";

import { Gauge, Play, Timer, Zap } from "lucide-react";
import { motion } from "motion/react";
import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { gameApi } from "@/features/gameplay/client-api";
import { useMessages } from "@/i18n";
import { playSfx } from "@/lib/audio/sfx";
import { cn } from "@/lib/utils";
import { useGame } from "@/stores/game";
import { useSettings } from "@/stores/settings";
import type { CategorySelection, QuestionCategory } from "@/types/game";
import { CATEGORY_COLORS, CategoryIcon } from "./CategoryIcon";

const RULE_ICONS = [Timer, Zap, Gauge];

export function SetupScreen() {
  const { m, locale } = useMessages();
  const soundOn = useSettings((s) => s.soundOn);
  const category = useGame((s) => s.category);
  const setCategory = useGame((s) => s.setCategory);
  const beginCountdown = useGame((s) => s.beginCountdown);
  const [categories, setCategories] = useState<QuestionCategory[] | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let cancelled = false;
    gameApi
      .categories(locale)
      .then((r) => !cancelled && setCategories(r.categories))
      .catch(() => {
        if (cancelled) return;
        setFailed(true);
        setCategories([]);
      });
    return () => {
      cancelled = true;
    };
  }, [locale]);

  const options: CategorySelection[] = ["mixed", ...(categories ?? [])];

  return (
    <motion.section initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} className="mx-auto w-full max-w-2xl px-4 pb-12">
      <div className="text-center">
        <h1 className="font-display text-4xl font-extrabold tracking-tight sm:text-5xl">
          <span className="text-gradient">{m.setup.title}</span>
        </h1>
        <p className="mt-2 text-muted">{m.setup.subtitle}</p>
      </div>

      <ul className="mt-6 grid gap-2 sm:grid-cols-3">
        {m.setup.rules.map((rule, i) => {
          const Icon = RULE_ICONS[i];
          return (
            <li key={rule} className="card-glass flex items-center gap-3 rounded-2xl px-4 py-3 text-sm">
              <Icon className="h-5 w-5 shrink-0 text-secondary" aria-hidden="true" />
              {rule}
            </li>
          );
        })}
      </ul>

      <h2 className="mt-8 mb-3 text-sm font-bold uppercase tracking-widest text-muted">{m.setup.chooseCategory}</h2>
      <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-3" role="radiogroup" aria-label={m.setup.chooseCategory}>
        {categories === null
          ? Array.from({ length: 6 }, (_, i) => <div key={i} className="h-16 rounded-2xl bg-white/5 shimmer" />)
          : options.map((c) => {
              const active = c === category;
              return (
                <button
                  key={c}
                  type="button"
                  role="radio"
                  aria-checked={active}
                  data-testid={`category-${c}`}
                  onClick={() => {
                    setCategory(c);
                    playSfx("select", soundOn);
                  }}
                  className={cn(
                    "flex h-16 items-center gap-3 rounded-2xl px-4 text-left text-sm font-semibold ring-2 transition-all",
                    active ? "bg-white/10 ring-primary-soft" : "bg-surface/80 ring-line/60 hover:ring-line",
                  )}
                  style={active ? { boxShadow: `0 0 24px -8px ${CATEGORY_COLORS[c]}` } : undefined}
                >
                  <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl" style={{ background: `${CATEGORY_COLORS[c]}22`, color: CATEGORY_COLORS[c] }}>
                    <CategoryIcon category={c} className="h-5 w-5" />
                  </span>
                  <span className="leading-tight">{m.categories[c]}</span>
                </button>
              );
            })}
      </div>
      {failed && <p role="status" className="mt-3 text-sm text-gold">{m.setup.categoriesError}</p>}

      <div className="mt-8 flex flex-col items-center gap-3">
        <Button
          size="xl"
          className="w-full sm:w-auto"
          data-testid="start-match"
          onClick={() => {
            playSfx("start", soundOn);
            beginCountdown();
          }}
        >
          <Play className="h-6 w-6 fill-current" /> {m.setup.start}
        </Button>
        <p className="hidden text-xs text-muted sm:block">{m.setup.keyboardHint}</p>
      </div>
    </motion.section>
  );
}
