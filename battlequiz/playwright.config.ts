import { defineConfig, devices } from "@playwright/test";

const PORT = Number(process.env.E2E_PORT ?? 3100);

/**
 * E2E tests run against a production build: `npm run build && npm run test:e2e`.
 * Without DATABASE_URL the server uses the in-memory development store.
 */
export default defineConfig({
  testDir: "tests/e2e",
  timeout: 120_000,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [["github"], ["list"]] : "list",
  use: { baseURL: `http://localhost:${PORT}`, trace: "retain-on-failure" },
  projects: [
    { name: "desktop", use: { ...devices["Desktop Chrome"] } },
    { name: "mobile", use: { ...devices["Pixel 7"] } },
  ],
  webServer: {
    command: `npx next start -p ${PORT}`,
    url: `http://localhost:${PORT}/api/health`,
    reuseExistingServer: !process.env.CI,
    env: {
      BATTLEQUIZ_ALLOW_MEMORY_STORE: process.env.DATABASE_URL ? "false" : "true",
      GUEST_COOKIE_SECRET: process.env.GUEST_COOKIE_SECRET ?? "e2e-only-secret-not-for-production-0123456789",
    },
  },
});
