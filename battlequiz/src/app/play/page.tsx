import type { Metadata } from "next";
import { AppShell } from "@/components/app/AppShell";

export const metadata: Metadata = { title: "Gioca · BattleQuiz" };

export default function PlayPage() {
  return <AppShell initialTab="play" />;
}
