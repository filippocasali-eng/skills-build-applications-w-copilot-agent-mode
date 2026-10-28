import type { CapacitorConfig } from "@capacitor/cli";

/** Android app shell: serves the offline static export (`out/`) from the device. */
const config: CapacitorConfig = {
  appId: "app.battlequiz.game",
  appName: "BattleQuiz",
  webDir: "out",
  backgroundColor: "#0B1020",
  plugins: {
    // Edge-to-edge with safe-area CSS variables (--safe-area-inset-*) and light icons on our dark UI.
    SystemBars: { insetsHandling: "css", initialViewportFitValueHint: "cover", style: "DARK" },
  },
  android: {
    allowMixedContent: false,
    webContentsDebuggingEnabled: false,
  },
};

export default config;
