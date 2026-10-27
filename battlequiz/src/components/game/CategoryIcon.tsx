import {
  Clapperboard,
  Cpu,
  FlaskConical,
  Gamepad2,
  Globe,
  Landmark,
  Leaf,
  Lightbulb,
  Music,
  Palette,
  Puzzle,
  Shuffle,
  Sparkles,
  Trophy,
  UtensilsCrossed,
  type LucideIcon,
} from "lucide-react";
import type { CategorySelection } from "@/types/game";

export const CATEGORY_ICONS: Record<CategorySelection, LucideIcon> = {
  mixed: Shuffle,
  general: Lightbulb,
  history: Landmark,
  geography: Globe,
  science: FlaskConical,
  technology: Cpu,
  movies_tv: Clapperboard,
  music: Music,
  sports: Trophy,
  nature: Leaf,
  food: UtensilsCrossed,
  art: Palette,
  logic: Puzzle,
  video_games: Gamepad2,
  pop_culture: Sparkles,
};

/** Accent colour per category, used for chips and glows. */
export const CATEGORY_COLORS: Record<CategorySelection, string> = {
  mixed: "#a78bfa",
  general: "#fbbf24",
  history: "#f59e0b",
  geography: "#22c55e",
  science: "#06b6d4",
  technology: "#38bdf8",
  movies_tv: "#f472b6",
  music: "#e879f9",
  sports: "#fb923c",
  nature: "#4ade80",
  food: "#f87171",
  art: "#c084fc",
  logic: "#facc15",
  video_games: "#818cf8",
  pop_culture: "#fb7185",
};

export function CategoryIcon({ category, className }: { category: CategorySelection; className?: string }) {
  const Icon = CATEGORY_ICONS[category];
  return <Icon className={className} aria-hidden="true" />;
}
