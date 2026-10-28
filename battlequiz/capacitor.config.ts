import type { CapacitorConfig } from "@capacitor/cli";

/** Android app shell: serves the offline static export (`out/`) from the device. */
const config: CapacitorConfig = {
  appId: "app.battlequiz.game",
  appName: "BattleQuiz",
  webDir: "out",
  backgroundColor: "#0B1020",
  android: {
    allowMixedContent: false,
    webContentsDebuggingEnabled: false,
  },
};

export default config;
