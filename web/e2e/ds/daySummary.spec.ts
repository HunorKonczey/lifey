import type { Page } from "@playwright/test";
import { test, expect } from "./fixtures";

/** The meals tab's day summary (W2.2) against the gallery's section (EN): the
 *  ring number and caption per state, eaten / goal beside it, and three macro
 *  rows — "68 / 120 g" with a bar, value only without a goal. */

function card(page: Page, name: "remaining" | "over" | "no-goal") {
  return page.locator(`#day-summary [data-state="${name}"]`);
}

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Day summary", exact: true }).scrollIntoViewIfNeeded();
});

test("under budget: 859 left, eaten and goal, three macro rows with grams of goal", async ({ page }) => {
  const c = card(page, "remaining");
  await expect(c.getByText("Daily summary")).toBeVisible();
  await expect(c.getByTestId("summary-number")).toHaveText("859");
  await expect(c.getByTestId("summary-caption")).toHaveText("kcal left");
  await expect(c.getByText("Eaten", { exact: true })).toBeVisible();
  await expect(c.getByText("Goal", { exact: true })).toBeVisible();
  await expect(c.getByTestId("summary-protein")).toContainText("68 / 120 g");
  await expect(c.getByTestId("summary-carbs")).toContainText("112 / 210 g");
  await expect(c.getByTestId("summary-fat")).toContainText("34 / 63 g");
});

test("over budget: the overage and the caption say so", async ({ page }) => {
  const c = card(page, "over");
  await expect(c.getByTestId("summary-number")).toHaveText("212");
  await expect(c.getByTestId("summary-caption")).toHaveText("kcal over");
});

test("no goal: what was eaten, no goal line, macros without a target", async ({ page }) => {
  const c = card(page, "no-goal");
  await expect(c.getByTestId("summary-number")).toHaveText("640");
  await expect(c.getByTestId("summary-caption")).toHaveText("kcal eaten");
  await expect(c.getByText("Goal", { exact: true })).toHaveCount(0);
  await expect(c.getByTestId("summary-protein")).toHaveText(/Protein\s*41 g$/);
});

test("no fibre or sugar rows — just the three macros", async ({ page }) => {
  const c = card(page, "remaining");
  await expect(c.locator('[data-testid^="summary-"]').filter({ hasNot: page.locator("svg") })).toHaveCount(5); // number, caption, 3 macros
  await expect(c.getByText(/fibre|sugar|rost|cukor/i)).toHaveCount(0);
});
