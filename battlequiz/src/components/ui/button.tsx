import { Slot } from "./slot";
import { cva, type VariantProps } from "class-variance-authority";
import * as React from "react";
import { cn } from "@/lib/utils";

/** shadcn/ui-style button, themed for BattleQuiz. */
const buttonVariants = cva(
  "relative inline-flex select-none items-center justify-center gap-2 whitespace-nowrap rounded-2xl font-semibold transition-[transform,background-color,box-shadow,opacity] duration-150 active:scale-[0.97] disabled:pointer-events-none disabled:opacity-50 [&_svg]:shrink-0",
  {
    variants: {
      variant: {
        primary:
          "bg-gradient-to-b from-[#8b5cf6] to-primary text-white shadow-[0_10px_30px_-10px_rgb(124_58_237/0.8),inset_0_1px_0_rgb(255_255_255/0.25)] hover:brightness-110",
        secondary:
          "bg-gradient-to-b from-[#22d3ee] to-secondary text-[#04212a] shadow-[0_10px_30px_-12px_rgb(6_182_212/0.8),inset_0_1px_0_rgb(255_255_255/0.35)] hover:brightness-110",
        gold: "bg-gradient-to-b from-[#fcd34d] to-gold text-[#3b2600] shadow-[0_10px_30px_-12px_rgb(251_191_36/0.8),inset_0_1px_0_rgb(255_255_255/0.4)] hover:brightness-105",
        ghost: "bg-white/5 text-text ring-1 ring-white/10 hover:bg-white/10",
        outline: "bg-transparent text-text ring-1 ring-line hover:bg-white/5",
      },
      size: {
        sm: "h-9 px-3 text-sm",
        md: "h-11 px-5 text-base",
        lg: "h-14 px-7 text-lg",
        xl: "h-16 px-9 text-xl",
        icon: "h-11 w-11",
      },
    },
    defaultVariants: { variant: "primary", size: "md" },
  },
);

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement>, VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

export function Button({ className, variant, size, asChild, ...props }: ButtonProps) {
  const Comp = asChild ? Slot : "button";
  return <Comp className={cn(buttonVariants({ variant, size }), className)} {...props} />;
}

export { buttonVariants };
