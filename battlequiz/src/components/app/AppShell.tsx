"use client";

import { AnimatePresence, motion } from "motion/react";
import { useEffect, useRef, useState, useSyncExternalStore } from "react";
import { LogoMark } from "@/components/layout/Logo";
import { initNative } from "@/lib/native";
import { useGame } from "@/stores/game";
import { useNav, type Screen, type Tab } from "@/stores/nav";
import { usePlayer } from "@/stores/player";
import { HistoryScreen } from "./HistoryScreen";
import { HomeScreen } from "./HomeScreen";
import { IN_MATCH_PHASES, MatchFlow, useMatchUi } from "./MatchFlow";
import { Onboarding } from "./Onboarding";
import { PlayScreen } from "./PlayScreen";
import { ProfileScreen } from "./ProfileScreen";
import { SettingsScreen } from "./SettingsScreen";
import { TabBar } from "./TabBar";
import { TrophiesScreen } from "./TrophiesScreen";

const TAB_SCREENS: Record<Tab, () => React.ReactNode> = {
  home: HomeScreen,
  play: PlayScreen,
  trophies: TrophiesScreen,
  profile: ProfileScreen,
};

function StackScreen({ screen }: { screen: Screen }) {
  if (screen.name === "match") return <MatchFlow mode={screen.mode} category={screen.category} />;
  if (screen.name === "settings") return <SettingsScreen />;
  return <HistoryScreen />;
}

/**
 * Android hardware back: close the quit sheet, confirm leaving a live match,
 * pop a pushed screen, return to Home, or let the app go to background.
 */
function handleBack(): boolean {
  const nav = useNav.getState();
  const top = nav.stack[nav.stack.length - 1];
  if (useMatchUi.getState().quitOpen) {
    useMatchUi.setState({ quitOpen: false });
    return true;
  }
  if (top?.name === "match" && IN_MATCH_PHASES.includes(useGame.getState().phase)) {
    useMatchUi.setState({ quitOpen: true });
    return true;
  }
  if (top) {
    if (top.name === "match") useGame.getState().reset();
    nav.pop();
    return true;
  }
  if (nav.tab !== "home") {
    nav.setTab("home");
    return true;
  }
  return false;
}

const noopSubscribe = () => () => undefined;

/**
 * Mobile app shell. Rendered only in the browser: everything in it depends on
 * on-device state (profile, progress, clock), so prerendering would be wrong.
 */
export function AppShell({ initialTab = "home" }: { initialTab?: Tab }) {
  const isClient = useSyncExternalStore(noopSubscribe, () => true, () => false);
  if (!isClient) {
    return (
      <div className="fixed inset-0 grid place-items-center bg-bg" aria-busy="true">
        <LogoMark className="h-20 w-20 animate-pulse" />
      </div>
    );
  }
  return <AppShellClient initialTab={initialTab} />;
}

function AppShellClient({ initialTab }: { initialTab: Tab }) {
  const tab = useNav((s) => s.tab);
  const stack = useNav((s) => s.stack);
  const onboarded = usePlayer((s) => s.onboarded);
  const [hydrated, setHydrated] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    useNav.setState({ tab: initialTab, stack: [] });
  }, [initialTab]);

  useEffect(() => {
    // Wait for persisted profile before deciding whether to show onboarding.
    const done = () => setHydrated(true);
    if (usePlayer.persist.hasHydrated()) done();
    return usePlayer.persist.onFinishHydration(done);
  }, []);

  useEffect(() => {
    let cleanup: (() => void) | undefined;
    void initNative(handleBack).then((c) => (cleanup = c));
    return () => cleanup?.();
  }, []);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: 0 });
  }, [tab]);

  const TabScreen = TAB_SCREENS[tab];
  const top = stack[stack.length - 1];

  return (
    <div className="app-root fixed inset-0 mx-auto flex max-w-[480px] flex-col overflow-hidden bg-bg sm:border-x sm:border-white/5">
      <div ref={scrollRef} className="no-scrollbar safe-top relative flex-1 overflow-y-auto overscroll-contain">
        <AnimatePresence mode="wait" initial={false}>
          <motion.div key={tab} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={{ duration: 0.18 }}>
            <TabScreen />
          </motion.div>
        </AnimatePresence>
      </div>
      <TabBar />

      <AnimatePresence>
        {top && (
          <motion.div
            key={stack.length + top.name}
            initial={{ x: "100%" }}
            animate={{ x: 0 }}
            exit={{ x: "100%" }}
            transition={{ type: "spring", stiffness: 380, damping: 40 }}
            className={top.name === "match" ? "absolute inset-0 z-40 bg-bg" : "no-scrollbar absolute inset-0 z-40 overflow-y-auto bg-bg"}
          >
            <StackScreen screen={top} />
          </motion.div>
        )}
      </AnimatePresence>

      <AnimatePresence>{hydrated && !onboarded && <Onboarding />}</AnimatePresence>
    </div>
  );
}
