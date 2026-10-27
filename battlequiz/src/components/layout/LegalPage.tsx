"use client";

import { ArrowLeft, FileWarning } from "lucide-react";
import Link from "next/link";
import { LEGAL, type LegalDoc } from "@/features/legal/content";
import { useMessages } from "@/i18n";
import { LanguageSwitch } from "./Controls";
import { Logo } from "./Logo";
import { SiteFooter } from "./SiteFooter";

export function LegalPage({ doc }: { doc: LegalDoc }) {
  const { m, locale } = useMessages();
  const content = LEGAL[doc][locale];
  return (
    <div className="flex min-h-dvh flex-col">
      <header className="mx-auto flex w-full max-w-3xl items-center justify-between px-4 py-4">
        <Link href="/"><Logo /></Link>
        <LanguageSwitch />
      </header>
      <main className="mx-auto w-full max-w-3xl flex-1 px-4 pb-16">
        <p role="note" className="flex items-center gap-2 rounded-2xl bg-gold/10 px-4 py-3 text-sm font-semibold text-gold ring-1 ring-gold/40">
          <FileWarning className="h-5 w-5 shrink-0" aria-hidden="true" /> {m.legal.draftBanner}
        </p>
        <h1 className="mt-8 font-display text-4xl font-extrabold">{content.title}</h1>
        <p className="mt-1 text-sm text-muted">{content.updated}</p>
        <div className="mt-8 space-y-8">
          {content.sections.map((s) => (
            <section key={s.h}>
              <h2 className="font-display text-xl font-bold">{s.h}</h2>
              {s.p.map((p) => (
                <p key={p} className="mt-2 leading-relaxed text-muted">{p}</p>
              ))}
            </section>
          ))}
        </div>
        <Link href="/" className="mt-10 inline-flex items-center gap-2 text-sm text-primary-soft hover:underline">
          <ArrowLeft className="h-4 w-4" /> {m.legal.back}
        </Link>
      </main>
      <SiteFooter />
    </div>
  );
}
