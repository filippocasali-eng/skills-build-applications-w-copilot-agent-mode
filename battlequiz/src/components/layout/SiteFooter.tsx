"use client";

import Link from "next/link";
import { useMessages } from "@/i18n";
import { Logo } from "./Logo";

export function SiteFooter() {
  const { m } = useMessages();
  return (
    <footer className="border-t border-white/5 py-10">
      <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-6 px-4 sm:flex-row">
        <div className="flex flex-col items-center gap-1 sm:items-start">
          <Logo />
          <p className="text-xs text-muted">{m.brand.tagline}</p>
        </div>
        <nav className="flex flex-wrap items-center justify-center gap-5 text-sm text-muted">
          <Link className="hover:text-text" href="/privacy">{m.footer.privacy}</Link>
          <Link className="hover:text-text" href="/terms">{m.footer.terms}</Link>
          <Link className="hover:text-text" href="/cookies">{m.footer.cookies}</Link>
        </nav>
        <p className="text-center text-xs text-muted">
          © 2026 BattleQuiz. {m.footer.rights}
          <br />
          <span className="text-muted/70">{m.footer.draft}</span>
        </p>
      </div>
    </footer>
  );
}
