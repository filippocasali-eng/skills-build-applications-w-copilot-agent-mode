"use client";

import {
  CalendarDays,
  Check,
  ChevronDown,
  Crown,
  Flame,
  Medal,
  Play,
  Radio,
  Sparkles,
  Swords,
  Trophy,
  Zap,
  type LucideIcon,
} from "lucide-react";
import { motion } from "motion/react";
import Link from "next/link";
import { useEffect, useState } from "react";
import { LanguageSwitch } from "@/components/layout/Controls";
import { Logo } from "@/components/layout/Logo";
import { SiteFooter } from "@/components/layout/SiteFooter";
import { Button } from "@/components/ui/button";
import { useMessages } from "@/i18n";
import { cn } from "@/lib/utils";

const FEATURE_ICONS: Record<string, LucideIcon> = {
  quick: Zap,
  daily: CalendarDays,
  friends: Swords,
  live: Radio,
  ranks: Trophy,
  rewards: Medal,
};

const fadeUp = {
  initial: { opacity: 0, y: 24 },
  whileInView: { opacity: 1, y: 0 },
  viewport: { once: true, margin: "-80px" },
  transition: { duration: 0.5 },
};

/** Decorative animated question card in the hero (a sample, not live data). */
function HeroDemo() {
  const { m } = useMessages();
  const [picked, setPicked] = useState<number | null>(null);
  useEffect(() => {
    const t = setInterval(() => setPicked((p) => (p === null ? 0 : null)), 2600);
    return () => clearInterval(t);
  }, []);
  return (
    <div className="relative mx-auto w-full max-w-md" aria-hidden="true">
      <div className="absolute -inset-6 rounded-[2.5rem] bg-gradient-to-br from-primary/40 via-transparent to-secondary/30 blur-2xl" />
      <motion.div
        initial={{ rotate: -2, y: 20, opacity: 0 }}
        animate={{ rotate: 2, y: 0, opacity: 1 }}
        transition={{ duration: 0.8, type: "spring" }}
        className="card-glass relative rounded-[2rem] p-5"
      >
        <div className="flex items-center justify-between text-xs font-bold">
          <span className="rounded-full bg-secondary/15 px-2.5 py-1 text-secondary">{m.categories.science}</span>
          <span className="flex items-center gap-1 rounded-full bg-gold/15 px-2.5 py-1 text-gold">
            <Flame className="h-3.5 w-3.5 fill-current" /> 4
          </span>
          <span className="grid h-10 w-10 place-items-center rounded-full font-display text-base font-black text-secondary ring-4 ring-secondary/60">9</span>
        </div>
        <p className="mt-4 font-display text-lg font-bold">{m.landing.demoQuestion}</p>
        <div className="mt-4 grid gap-2">
          {m.landing.demoOptions.map((o, i) => (
            <div
              key={o}
              className={cn(
                "flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-semibold ring-2 transition-all duration-500",
                picked === 0 && i === 0 ? "bg-success/20 ring-success shadow-[0_0_24px_-6px_rgb(34_197_94/0.8)]" : "bg-surface-2/80 ring-line",
                picked === 0 && i !== 0 && "opacity-50",
              )}
            >
              <span className={cn("grid h-7 w-7 place-items-center rounded-lg text-xs font-black", picked === 0 && i === 0 ? "bg-success text-[#052e14]" : "bg-white/10")}>
                {picked === 0 && i === 0 ? <Check className="h-4 w-4" /> : "ABCD"[i]}
              </span>
              {o}
            </div>
          ))}
        </div>
        <motion.div
          animate={picked === 0 ? { opacity: 1, y: 0, scale: 1 } : { opacity: 0, y: 10, scale: 0.8 }}
          className="absolute -right-3 -top-4 rounded-2xl bg-gradient-to-b from-[#fcd34d] to-gold px-3 py-1.5 font-display text-lg font-black text-[#3b2600] shadow-lg"
        >
          +234
        </motion.div>
      </motion.div>
    </div>
  );
}

export function LandingPage() {
  const { m, locale } = useMessages();
  const [openFaq, setOpenFaq] = useState<number | null>(0);

  return (
    <div className="flex min-h-dvh flex-col">
      <header className="sticky top-0 z-40 border-b border-white/5 bg-bg/70 backdrop-blur-xl">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3">
          <Link href="/" aria-label="BattleQuiz">
            <Logo />
          </Link>
          <nav className="hidden items-center gap-6 text-sm text-muted md:flex">
            <a href="#modes" className="hover:text-text">{m.nav.features}</a>
            <a href="#how" className="hover:text-text">{m.nav.how}</a>
            <a href="#pricing" className="hover:text-text">{m.nav.pricing}</a>
            <a href="#faq" className="hover:text-text">{m.nav.faq}</a>
          </nav>
          <div className="flex items-center gap-2">
            <LanguageSwitch />
            <Button asChild size="sm" className="hidden sm:inline-flex">
              <Link href="/play">{m.common.playNow}</Link>
            </Button>
          </div>
        </div>
      </header>

      <main className="flex-1">
        {/* Hero */}
        <section className="mx-auto grid max-w-6xl items-center gap-12 px-4 pb-16 pt-12 md:grid-cols-[1.1fr_1fr] md:pt-20">
          <div>
            <motion.span initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="inline-flex items-center gap-2 rounded-full bg-white/5 px-3 py-1.5 text-xs font-semibold text-primary-soft ring-1 ring-primary/40">
              <Sparkles className="h-3.5 w-3.5" /> {m.landing.heroBadge}
            </motion.span>
            <h1 className="mt-5 font-display text-5xl font-black leading-[1.02] tracking-tight sm:text-6xl lg:text-7xl">
              {[m.landing.heroTitle1, m.landing.heroTitle2, m.landing.heroTitle3].map((line, i) => (
                <motion.span key={line} initial={{ opacity: 0, x: -20 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: 0.1 + i * 0.12 }} className={cn("block", i === 1 && "text-gradient", i === 2 && "text-gold-gradient")}>
                  {line}
                </motion.span>
              ))}
            </h1>
            <p className="mt-6 max-w-xl text-lg text-muted">{m.landing.heroText}</p>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              <Button asChild size="xl" data-testid="hero-play">
                <Link href="/play">
                  <Play className="h-6 w-6 fill-current" /> {m.common.playNow}
                </Link>
              </Button>
              <Button asChild size="xl" variant="ghost">
                <a href="#how">{m.landing.heroSecondary}</a>
              </Button>
            </div>
            <dl className="mt-10 grid max-w-md grid-cols-3 gap-4">
              {m.landing.heroStats.map((s) => (
                <div key={s.label}>
                  <dt className="sr-only">{s.label}</dt>
                  <dd className="font-display text-2xl font-extrabold">{s.value}</dd>
                  <dd className="text-xs text-muted">{s.label}</dd>
                </div>
              ))}
            </dl>
          </div>
          <HeroDemo />
        </section>

        {/* Modes */}
        <section id="modes" className="mx-auto max-w-6xl scroll-mt-20 px-4 py-16">
          <motion.div {...fadeUp} className="text-center">
            <h2 className="font-display text-3xl font-extrabold sm:text-4xl">{m.landing.featuresTitle}</h2>
            <p className="mt-2 text-muted">{m.landing.featuresText}</p>
          </motion.div>
          <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {m.landing.features.map((f, i) => {
              const Icon = FEATURE_ICONS[f.key];
              const live = f.key === "quick";
              return (
                <motion.article key={f.key} {...fadeUp} transition={{ duration: 0.5, delay: i * 0.06 }} className={cn("card-glass relative rounded-3xl p-6", live && "ring-2 ring-primary/60")}>
                  <div className="flex items-start justify-between">
                    <span className={cn("grid h-12 w-12 place-items-center rounded-2xl", live ? "bg-primary text-white" : "bg-white/5 text-primary-soft")}>
                      <Icon className="h-6 w-6" aria-hidden="true" />
                    </span>
                    <span className={cn("rounded-full px-2.5 py-1 text-[11px] font-bold uppercase tracking-wide", live ? "bg-success/15 text-success" : "bg-white/5 text-muted")}>
                      {live ? m.common.available : m.common.comingSoon}
                    </span>
                  </div>
                  <h3 className="mt-4 font-display text-xl font-bold">{f.title}</h3>
                  <p className="mt-1 text-sm text-muted">{f.text}</p>
                </motion.article>
              );
            })}
          </div>
        </section>

        {/* How it works */}
        <section id="how" className="mx-auto max-w-6xl scroll-mt-20 px-4 py-16">
          <motion.h2 {...fadeUp} className="text-center font-display text-3xl font-extrabold sm:text-4xl">{m.landing.howTitle}</motion.h2>
          <ol className="mt-10 grid gap-4 md:grid-cols-3">
            {m.landing.howSteps.map((s, i) => (
              <motion.li key={s.title} {...fadeUp} transition={{ duration: 0.5, delay: i * 0.1 }} className="card-glass rounded-3xl p-6">
                <span className="font-display text-5xl font-black text-gradient">{i + 1}</span>
                <h3 className="mt-2 font-display text-xl font-bold">{s.title}</h3>
                <p className="mt-1 text-sm text-muted">{s.text}</p>
              </motion.li>
            ))}
          </ol>
        </section>

        {/* Leaderboard preview (clearly labelled sample) */}
        <section className="mx-auto max-w-3xl px-4 py-16">
          <motion.div {...fadeUp} className="text-center">
            <h2 className="font-display text-3xl font-extrabold sm:text-4xl">{m.landing.leaderboardTitle}</h2>
            <p className="mt-2 text-muted">{m.landing.leaderboardText}</p>
          </motion.div>
          <motion.div {...fadeUp} className="card-glass relative mt-8 rounded-3xl p-4">
            <span className="absolute right-4 top-4 rounded-full bg-white/10 px-2.5 py-1 text-[11px] font-bold uppercase text-muted">{m.common.example}</span>
            <ol className="space-y-2 pt-8">
              {m.landing.leaderboardSample.map((row, i) => (
                <li key={row.name} className="flex items-center gap-4 rounded-2xl bg-white/5 px-4 py-3">
                  <span className={cn("grid h-9 w-9 place-items-center rounded-xl font-display font-black", i === 0 ? "bg-gold text-[#3b2600]" : i === 1 ? "bg-slate-300 text-slate-900" : "bg-amber-700 text-amber-50")}>
                    {i === 0 ? <Crown className="h-5 w-5" /> : i + 1}
                  </span>
                  <span className="flex-1 font-semibold">{row.name}</span>
                  <span className="font-display font-extrabold tabular-nums text-gold">{row.score.toLocaleString(locale)}</span>
                </li>
              ))}
            </ol>
            <p className="mt-3 text-center text-xs text-muted">{m.landing.leaderboardNote}</p>
          </motion.div>
        </section>

        {/* Pricing */}
        <section id="pricing" className="mx-auto max-w-5xl scroll-mt-20 px-4 py-16">
          <motion.div {...fadeUp} className="text-center">
            <h2 className="font-display text-3xl font-extrabold sm:text-4xl">{m.landing.pricingTitle}</h2>
            <p className="mt-2 text-muted">{m.landing.pricingText}</p>
          </motion.div>
          <div className="mt-10 grid gap-4 md:grid-cols-2">
            {[m.landing.free, m.landing.plus].map((plan, i) => (
              <motion.div key={plan.name} {...fadeUp} className={cn("card-glass rounded-3xl p-7", i === 1 && "ring-2 ring-gold/50")}>
                <h3 className={cn("font-display text-2xl font-extrabold", i === 1 && "text-gold-gradient")}>{plan.name}</h3>
                <p className="mt-3">
                  <span className="font-display text-4xl font-black">{plan.price}</span> <span className="text-muted">{plan.period}</span>
                </p>
                <ul className="mt-5 space-y-2.5 text-sm">
                  {plan.items.map((it) => (
                    <li key={it} className="flex items-center gap-2">
                      <Check className={cn("h-4 w-4 shrink-0", i === 1 ? "text-gold" : "text-success")} aria-hidden="true" /> {it}
                    </li>
                  ))}
                </ul>
                {i === 0 ? (
                  <Button asChild className="mt-7 w-full" size="lg">
                    <Link href="/play">{m.common.playNow}</Link>
                  </Button>
                ) : (
                  <>
                    <Button className="mt-7 w-full" size="lg" variant="gold" disabled>
                      {m.common.comingSoon}
                    </Button>
                    <p className="mt-3 text-xs text-muted">{m.landing.plus.note}</p>
                  </>
                )}
              </motion.div>
            ))}
          </div>
        </section>

        {/* FAQ */}
        <section id="faq" className="mx-auto max-w-3xl scroll-mt-20 px-4 py-16">
          <motion.h2 {...fadeUp} className="text-center font-display text-3xl font-extrabold sm:text-4xl">{m.landing.faqTitle}</motion.h2>
          <div className="mt-8 space-y-3">
            {m.landing.faq.map((f, i) => {
              const open = openFaq === i;
              return (
                <div key={f.q} className="card-glass rounded-2xl">
                  <button type="button" aria-expanded={open} onClick={() => setOpenFaq(open ? null : i)} className="flex w-full items-center justify-between gap-4 px-5 py-4 text-left font-semibold">
                    {f.q}
                    <ChevronDown className={cn("h-5 w-5 shrink-0 transition-transform", open && "rotate-180")} />
                  </button>
                  {open && <p className="px-5 pb-5 text-sm text-muted">{f.a}</p>}
                </div>
              );
            })}
          </div>
        </section>

        {/* CTA */}
        <section className="mx-auto max-w-4xl px-4 pb-20 pt-6">
          <motion.div {...fadeUp} className="relative overflow-hidden rounded-[2rem] bg-gradient-to-br from-primary via-[#5b21b6] to-[#0e7490] p-10 text-center">
            <div className="absolute -right-10 -top-10 h-48 w-48 rounded-full bg-gold/30 blur-3xl" />
            <h2 className="relative font-display text-3xl font-black sm:text-4xl">{m.landing.ctaTitle}</h2>
            <p className="relative mt-2 text-white/80">{m.landing.ctaText}</p>
            <Button asChild size="xl" variant="gold" className="relative mt-7">
              <Link href="/play">
                <Play className="h-6 w-6 fill-current" /> {m.common.playNow}
              </Link>
            </Button>
          </motion.div>
        </section>
      </main>
      <SiteFooter />
    </div>
  );
}
