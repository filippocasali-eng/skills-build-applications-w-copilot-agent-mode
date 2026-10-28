import type { Metadata, Viewport } from "next";
import { Inter, Outfit } from "next/font/google";
import { BackgroundFx } from "@/components/layout/BackgroundFx";
import { Providers } from "@/components/layout/Providers";
import { it } from "@/i18n/messages/it";
import "./globals.css";

const body = Inter({ variable: "--font-body", subsets: ["latin"], display: "swap" });
const display = Outfit({ variable: "--font-display-face", subsets: ["latin"], weight: ["600", "700", "800", "900"], display: "swap" });

export const metadata: Metadata = {
  title: it.meta.title,
  description: it.meta.description,
  applicationName: "BattleQuiz",
  openGraph: { title: "BattleQuiz", description: it.meta.description, type: "website", locale: "it_IT" },
};

export const viewport: Viewport = {
  themeColor: "#0B1020",
  width: "device-width",
  initialScale: 1,
  // Edge-to-edge on phones; safe areas are handled with the .safe-top/.safe-bottom utilities.
  viewportFit: "cover",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="it" className={`${body.variable} ${display.variable} h-full antialiased`}>
      <body className="min-h-full">
        <BackgroundFx />
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
