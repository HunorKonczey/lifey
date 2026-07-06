import { defineConfig, devices } from "@playwright/test";

/**
 * E2E tests exercise the real backend (docs/personal_trainer/07-utemterv-es-kockazatok.md
 * item 19) — unlike the Vitest unit suite, these are not mocked. Requires the
 * backend (localhost:8080) and its Postgres to already be running; only the
 * Next.js dev server is started here.
 */
export default defineConfig({
  testDir: "./e2e",
  fullyParallel: false,
  retries: process.env.CI ? 1 : 0,
  reporter: [["list"]],
  use: {
    baseURL: "http://localhost:3000",
    trace: "retain-on-failure",
    // Deterministic English UI regardless of the host machine's locale —
    // useLocale() (src/lib/hooks/useLocale.ts) falls back to navigator.language.
    locale: "en-US",
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
  ],
  webServer: {
    command: "npm run dev",
    url: "http://localhost:3000",
    reuseExistingServer: true,
    timeout: 60_000,
  },
});
