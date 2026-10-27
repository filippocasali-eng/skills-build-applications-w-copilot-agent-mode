import { cn } from "@/lib/utils";
import type { SlotResult } from "@/stores/game";

const COLORS: Record<SlotResult, string> = {
  correct: "bg-success shadow-[0_0_8px_rgb(34_197_94/0.7)]",
  wrong: "bg-error",
  timeout: "bg-gold/70",
};

export function ProgressSegments({ total, current, slots }: { total: number; current: number; slots: SlotResult[] }) {
  return (
    <div className="flex gap-1.5" aria-hidden="true">
      {Array.from({ length: total }, (_, i) => (
        <div
          key={i}
          className={cn(
            "h-2 flex-1 rounded-full transition-colors duration-300",
            slots[i] ? COLORS[slots[i]] : i === current ? "bg-primary-soft" : "bg-white/10",
          )}
        />
      ))}
    </div>
  );
}
