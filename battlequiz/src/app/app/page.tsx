import type { Metadata } from "next";
import { AppShell } from "@/components/app/AppShell";

export const metadata: Metadata = { title: "BattleQuiz" };

export default function AppPage() {
  return <AppShell />;
}
