"use client";

import { Gamepad2, Home, Trophy, User, type LucideIcon } from "lucide-react";
import { motion } from "motion/react";
import { useMessages } from "@/i18n";
import { haptic } from "@/lib/native";
import { cn } from "@/lib/utils";
import { useNav, type Tab } from "@/stores/nav";

const TABS: { id: Tab; icon: LucideIcon }[] = [
  { id: "home", icon: Home },
  { id: "play", icon: Gamepad2 },
  { id: "trophies", icon: Trophy },
  { id: "profile", icon: User },
];

export function TabBar() {
  const { m } = useMessages();
  const tab = useNav((s) => s.tab);
  const setTab = useNav((s) => s.setTab);
  return (
    <nav aria-label="BattleQuiz" className="safe-bottom relative z-30 border-t border-white/5 bg-[#0d1326]/90 backdrop-blur-2xl">
      <ul className="grid grid-cols-4 px-2 pt-1.5">
        {TABS.map(({ id, icon: Icon }) => {
          const active = tab === id;
          return (
            <li key={id}>
              <button
                type="button"
                data-testid={`tab-${id}`}
                aria-current={active ? "page" : undefined}
                onClick={() => {
                  if (!active) void haptic("tap");
                  setTab(id);
                }}
                className="relative flex w-full flex-col items-center gap-0.5 pb-2 pt-1.5"
              >
                {active && <motion.span layoutId="tab-pill" className="absolute top-0.5 h-8 w-16 rounded-full bg-primary/25" transition={{ type: "spring", stiffness: 500, damping: 38 }} />}
                <Icon className={cn("relative h-6 w-6 transition-colors", active ? "text-primary-soft" : "text-muted")} strokeWidth={active ? 2.4 : 2} />
                <span className={cn("relative text-[11px] font-bold transition-colors", active ? "text-text" : "text-muted")}>{m.app.tabs[id]}</span>
              </button>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
