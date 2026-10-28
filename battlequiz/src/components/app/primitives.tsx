"use client";

import { ChevronLeft } from "lucide-react";
import { AnimatePresence, motion, type HTMLMotionProps } from "motion/react";
import { useEffect, type ReactNode } from "react";
import { useMessages } from "@/i18n";
import { haptic } from "@/lib/native";
import { cn } from "@/lib/utils";

/** Tappable surface with native-like press feedback (scale + haptic). */
export function Pressable({ className, onClick, haptics = "tap", children, ...props }: HTMLMotionProps<"button"> & { haptics?: "tap" | "select" | false }) {
  return (
    <motion.button
      type="button"
      whileTap={{ scale: 0.96 }}
      transition={{ type: "spring", stiffness: 500, damping: 30 }}
      onClick={(e) => {
        if (haptics) void haptic(haptics);
        onClick?.(e);
      }}
      className={cn("select-none text-left disabled:cursor-not-allowed", className)}
      {...props}
    >
      {children}
    </motion.button>
  );
}

export function Avatar({ name, color, size = 44, className }: { name: string; color: string; size?: number; className?: string }) {
  const initial = (name.trim()[0] ?? "?").toUpperCase();
  return (
    <span
      aria-hidden="true"
      className={cn("grid shrink-0 place-items-center rounded-full font-display font-black text-white ring-2 ring-white/15", className)}
      style={{ width: size, height: size, fontSize: size * 0.42, background: `radial-gradient(circle at 30% 25%, ${color}, ${color}aa 55%, #0b1020 140%)`, boxShadow: `0 8px 24px -10px ${color}` }}
    >
      {initial}
    </span>
  );
}

export function ProgressBar({ value, className, color = "from-primary to-secondary" }: { value: number; className?: string; color?: string }) {
  return (
    <div className={cn("h-2.5 overflow-hidden rounded-full bg-white/10", className)}>
      <motion.div initial={{ width: 0 }} animate={{ width: `${Math.max(0, Math.min(1, value)) * 100}%` }} transition={{ duration: 0.8, ease: "easeOut" }} className={cn("h-full rounded-full bg-gradient-to-r", color)} />
    </div>
  );
}

export function SectionTitle({ children, action }: { children: ReactNode; action?: ReactNode }) {
  return (
    <div className="mb-3 mt-7 flex items-end justify-between px-1">
      <h2 className="font-display text-lg font-extrabold tracking-tight">{children}</h2>
      {action}
    </div>
  );
}

/** Top bar for pushed (stack) screens. */
export function ScreenHeader({ title, onBack, right }: { title: string; onBack: () => void; right?: ReactNode }) {
  const { m } = useMessages();
  return (
    <header className="safe-top sticky top-0 z-20 bg-bg/85 backdrop-blur-xl">
      <div className="flex h-14 items-center gap-2 px-2">
        <Pressable onClick={onBack} aria-label={m.app.back} className="grid h-11 w-11 place-items-center rounded-full text-text hover:bg-white/5">
          <ChevronLeft className="h-6 w-6" />
        </Pressable>
        <h1 className="flex-1 truncate font-display text-lg font-bold">{title}</h1>
        {right}
      </div>
    </header>
  );
}

export function Switch({ checked, onChange, label }: { checked: boolean; onChange: () => void; label: string }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      onClick={() => {
        void haptic("tap");
        onChange();
      }}
      className={cn("relative h-7 w-12 shrink-0 rounded-full transition-colors", checked ? "bg-primary" : "bg-white/15")}
    >
      <motion.span layout transition={{ type: "spring", stiffness: 600, damping: 35 }} className={cn("absolute top-1 h-5 w-5 rounded-full bg-white shadow", checked ? "right-1" : "left-1")} />
    </button>
  );
}

export function Segmented<T extends string>({ value, options, onChange, label }: { value: T; options: { value: T; label: string }[]; onChange: (v: T) => void; label: string }) {
  return (
    <div role="radiogroup" aria-label={label} className="flex rounded-xl bg-white/5 p-1 ring-1 ring-white/10">
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          role="radio"
          aria-checked={value === o.value}
          onClick={() => {
            void haptic("tap");
            onChange(o.value);
          }}
          className={cn("relative rounded-lg px-3 py-1.5 text-xs font-bold transition-colors", value === o.value ? "text-white" : "text-muted")}
        >
          {value === o.value && <motion.span layoutId={`seg-${label}`} className="absolute inset-0 rounded-lg bg-primary" transition={{ type: "spring", stiffness: 500, damping: 35 }} />}
          <span className="relative">{o.label}</span>
        </button>
      ))}
    </div>
  );
}

/** Bottom sheet dialog (modal). */
export function Sheet({ open, onClose, children, label }: { open: boolean; onClose: () => void; children: ReactNode; label: string }) {
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onClose]);
  return (
    <AnimatePresence>
      {open && (
        <div className="fixed inset-0 z-[60] flex items-end justify-center" role="dialog" aria-modal="true" aria-label={label}>
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={onClose} />
          <motion.div
            initial={{ y: "100%" }}
            animate={{ y: 0 }}
            exit={{ y: "100%" }}
            transition={{ type: "spring", stiffness: 380, damping: 36 }}
            className="safe-bottom relative w-full max-w-[480px] rounded-t-[2rem] bg-surface px-5 pt-3 ring-1 ring-white/10"
          >
            <div className="mx-auto mb-4 h-1.5 w-10 rounded-full bg-white/20" />
            {children}
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  );
}

export function timeAgo(at: number, now: number, ago: { now: string; minutes: string; hours: string; days: string }): string {
  const min = Math.floor((now - at) / 60_000);
  if (min < 1) return ago.now;
  if (min < 60) return ago.minutes.replace("{n}", String(min));
  const h = Math.floor(min / 60);
  if (h < 24) return ago.hours.replace("{n}", String(h));
  return ago.days.replace("{n}", String(Math.floor(h / 24)));
}

/** "4 h 12 min" until the next UTC midnight (daily challenge rollover). */
export function untilUtcMidnight(now: number): string {
  const d = new Date(now);
  const next = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() + 1);
  const mins = Math.max(0, Math.ceil((next - now) / 60_000));
  const h = Math.floor(mins / 60);
  return h > 0 ? `${h} h ${mins % 60} min` : `${mins} min`;
}
