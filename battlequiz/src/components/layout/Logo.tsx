import { cn } from "@/lib/utils";

/** Original BattleQuiz mark: a shield with a lightning-bolt "Q". */
export function LogoMark({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 48 48" className={cn("h-9 w-9", className)} aria-hidden="true">
      <defs>
        <linearGradient id="bq-shield" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#a78bfa" />
          <stop offset="0.5" stopColor="#7c3aed" />
          <stop offset="1" stopColor="#06b6d4" />
        </linearGradient>
        <linearGradient id="bq-bolt" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#fde68a" />
          <stop offset="1" stopColor="#fbbf24" />
        </linearGradient>
      </defs>
      <path d="M24 2 42 9v14c0 11.5-7.6 19.6-18 23C13.6 42.6 6 34.5 6 23V9l18-7Z" fill="url(#bq-shield)" />
      <path d="M24 5.5 39 11.3V23c0 9.6-6.2 16.5-15 19.6C15.2 39.5 9 32.6 9 23V11.3l15-5.8Z" fill="#0b1020" opacity="0.35" />
      <circle cx="23" cy="23" r="10.5" fill="none" stroke="#f8fafc" strokeWidth="3.4" />
      <path d="M30 27.5 36.5 36" stroke="#f8fafc" strokeWidth="3.6" strokeLinecap="round" />
      <path d="M25.5 13.5 18.5 24.5h5l-2 9 7.5-12h-5.2l1.7-8Z" fill="url(#bq-bolt)" stroke="#0b1020" strokeWidth="0.8" strokeLinejoin="round" />
    </svg>
  );
}

export function Logo({ className, size = "md" }: { className?: string; size?: "md" | "lg" }) {
  return (
    <span className={cn("inline-flex items-center gap-2", className)}>
      <LogoMark className={size === "lg" ? "h-12 w-12" : undefined} />
      <span className={cn("font-display font-extrabold tracking-tight", size === "lg" ? "text-3xl" : "text-xl")}>
        Battle<span className="text-gradient">Quiz</span>
      </span>
    </span>
  );
}
