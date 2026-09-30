import { defineConfig, devices } from "@playwright/test";

/**
 * E2E tests exercise the real backend (docs/personal_trainer/07-utemterv-es-kockazatok.md
 * item 19) — unlike the Vitest unit suite, these are not mocked. Requires the
 * backend (localhost:8080) and its Postgres to already be running; only the
 * Next.js dev server is started here.
 *
 * **Three projects.** `e2e/marketing/**` is entirely static pages, stubbed
 * routes and a signed-out visitor, so it needs no backend
 * (docs/landing_page/72 Prompt 4). `e2e/ds/**` drives the dev design gallery
 * (`/dev/design`, D-W0.12) — no backend either, since the gallery is fixture
 * data. Both run in CI (`web-ci.yml` runs `--project=marketing` and
 * `--project=ds`). Everything in `e2e/` outside those two folders stays a
 * local, backend-dependent run under `--project=chromium`.
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
    {
      name: "chromium",
      testIgnore: [/marketing[\\/]/, /ds[\\/]/],
      use: { ...devices["Desktop Chrome"] },
    },
    {
      name: "marketing",
      testDir: "./e2e/marketing",
      use: { ...devices["Desktop Chrome"] },
    },
    {
      name: "ds",
      testDir: "./e2e/ds",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  webServer: {
    command: "npm run dev",
    // Waiting on the gallery (not `/`) also compiles it before the first spec
    // runs, so a cold CI runner doesn't spend the first test's timeout on it.
    url: "http://localhost:3000/dev/design",
    reuseExistingServer: true,
    timeout: 120_000,
  },
});
