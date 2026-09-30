import type { Page } from "@playwright/test";
import { test, expect } from "./fixtures";

/** The dashboard's recommended-workout card (W1.4) against the gallery's
 *  section (EN): meta line, "4 × 8" only when reps are known, last-performed
 *  date, the start button, and the template-picker fallback. */

function card(page: Page, name: "with-history" | "no-history" | "picker") {
  return page.locator(`#recommended-workout [data-state="${name}"]`);
}

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Recommended workout", exact: true }).scrollIntoViewIfNeeded();
});

test("a suggestion shows its name, meta line, last date and three exercises with sets × reps", async ({ page }) => {
  const c = card(page, "with-history");
  await expect(c.getByRole("heading", { name: "Leg + core" })).toBeVisible();
  await expect(c.getByText("6 exercises · about 50 min · 18 sets")).toBeVisible();
  await expect(c.getByText("last Sep 23")).toBeVisible();
  await expect(c.getByText("4 × 8")).toBeVisible();
  await expect(c.getByText("3 × 12")).toBeVisible();
  await expect(c.getByRole("listitem")).toHaveCount(3);
  await expect(c.getByRole("button", { name: "Start workout" })).toBeVisible();
});

test("without history the exercise rows show sets only, and no last-performed date", async ({ page }) => {
  const c = card(page, "no-history");
  await expect(c.getByText("4 sets")).toBeVisible();
  await expect(c.getByText("3 sets")).toBeVisible();
  await expect(c.getByText(/^last /)).toHaveCount(0);
});

test("with no suggestion the card becomes a template picker instead of disappearing", async ({ page }) => {
  const c = card(page, "picker");
  await expect(c.getByRole("heading", { name: "Pick a template" })).toBeVisible();
  await expect(c.getByRole("button", { name: "Open templates" })).toBeVisible();
  await expect(c.getByRole("button", { name: "Start workout" })).toHaveCount(0);
});
