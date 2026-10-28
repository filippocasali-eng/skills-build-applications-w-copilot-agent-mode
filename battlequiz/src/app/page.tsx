import { AppShell } from "@/components/app/AppShell";
import { LandingPage } from "@/components/landing/LandingPage";

/** The web site opens on the landing page; the Android app opens straight into the game. */
export default function Home() {
  return process.env.NEXT_PUBLIC_BQ_OFFLINE === "1" ? <AppShell /> : <LandingPage />;
}
