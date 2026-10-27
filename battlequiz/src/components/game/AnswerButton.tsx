"use client";

import { Check, X } from "lucide-react";
import { motion } from "motion/react";
import { cn } from "@/lib/utils";

export type AnswerState = "idle" | "pending" | "correct" | "wrong" | "reveal" | "dim";

const LETTERS = ["A", "B", "C", "D"];

interface AnswerButtonProps {
  index: number;
  text: string;
  state: AnswerState;
  disabled: boolean;
  onSelect: (index: number) => void;
  ariaLabel: string;
}

const STYLES: Record<AnswerState, string> = {
  idle: "bg-surface-2/80 ring-line hover:ring-primary-soft hover:bg-surface-2 hover:-translate-y-0.5",
  pending: "bg-primary/25 ring-primary-soft shadow-[0_0_0_4px_rgb(124_58_237/0.25)]",
  correct: "bg-success/20 ring-success shadow-[0_0_30px_-6px_rgb(34_197_94/0.8)]",
  wrong: "bg-error/20 ring-error shadow-[0_0_30px_-8px_rgb(239_68_68/0.8)]",
  reveal: "bg-success/10 ring-success/80",
  dim: "bg-surface-2/40 ring-line/50 opacity-50",
};

const BADGE: Record<AnswerState, string> = {
  idle: "bg-white/10 text-text",
  pending: "bg-primary text-white",
  correct: "bg-success text-[#052e14]",
  wrong: "bg-error text-white",
  reveal: "bg-success/80 text-[#052e14]",
  dim: "bg-white/5 text-muted",
};

export function AnswerButton({ index, text, state, disabled, onSelect, ariaLabel }: AnswerButtonProps) {
  return (
    <motion.button
      type="button"
      data-testid={`answer-${index}`}
      data-state={state}
      aria-label={ariaLabel}
      disabled={disabled}
      onClick={() => onSelect(index)}
      initial={{ opacity: 0, y: 12 }}
      animate={
        state === "wrong"
          ? { opacity: 1, y: 0, x: [0, -8, 8, -6, 6, 0] }
          : state === "correct"
            ? { opacity: 1, y: 0, scale: [1, 1.04, 1] }
            : { opacity: 1, y: 0, x: 0, scale: 1 }
      }
      transition={{ duration: state === "idle" ? 0.25 : 0.4, delay: state === "idle" ? index * 0.05 : 0 }}
      className={cn(
        "group flex min-h-16 w-full items-center gap-3 rounded-2xl px-4 py-3 text-left text-base font-semibold ring-2 transition-[background-color,box-shadow,transform,opacity] duration-200 disabled:cursor-default sm:text-lg",
        STYLES[state],
      )}
    >
      <span className={cn("grid h-9 w-9 shrink-0 place-items-center rounded-xl font-display text-sm font-extrabold", BADGE[state])}>
        {state === "correct" || state === "reveal" ? <Check className="h-5 w-5" /> : state === "wrong" ? <X className="h-5 w-5" /> : LETTERS[index]}
      </span>
      <span className="flex-1 leading-snug">{text}</span>
    </motion.button>
  );
}
