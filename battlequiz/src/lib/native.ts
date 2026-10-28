"use client";

import { Capacitor } from "@capacitor/core";
import { useSettings } from "@/stores/settings";

/**
 * Thin wrapper over native capabilities. Everything degrades gracefully on the
 * web, and never throws: native polish must not break gameplay.
 */
export const isNative = () => Capacitor.isNativePlatform();

export type HapticKind = "tap" | "select" | "success" | "error" | "warning" | "heavy";

export async function haptic(kind: HapticKind): Promise<void> {
  if (!useSettings.getState().hapticsOn) return;
  try {
    if (isNative()) {
      const { Haptics, ImpactStyle, NotificationType } = await import("@capacitor/haptics");
      if (kind === "success") await Haptics.notification({ type: NotificationType.Success });
      else if (kind === "error") await Haptics.notification({ type: NotificationType.Error });
      else if (kind === "warning") await Haptics.notification({ type: NotificationType.Warning });
      else await Haptics.impact({ style: kind === "heavy" ? ImpactStyle.Heavy : kind === "select" ? ImpactStyle.Medium : ImpactStyle.Light });
    } else if (typeof navigator !== "undefined" && "vibrate" in navigator) {
      navigator.vibrate(kind === "error" ? [30, 40, 30] : kind === "success" ? 20 : 8);
    }
  } catch {
    // Haptics unavailable: ignore.
  }
}

/** One-time native setup: light status-bar icons over our dark UI, Android back button. */
export async function initNative(onBack: () => boolean): Promise<() => void> {
  if (!isNative()) return () => undefined;
  const cleanups: Array<() => void> = [];
  try {
    const { SystemBars, SystemBarsStyle } = await import("@capacitor/core");
    await SystemBars.setStyle({ style: SystemBarsStyle.Dark });
  } catch {
    // Older shells without SystemBars: keep defaults.
  }
  try {
    const { App } = await import("@capacitor/app");
    const handle = await App.addListener("backButton", () => {
      if (!onBack()) void App.minimizeApp();
    });
    cleanups.push(() => void handle.remove());
  } catch {
    // App plugin unavailable.
  }
  return () => cleanups.forEach((c) => c());
}
