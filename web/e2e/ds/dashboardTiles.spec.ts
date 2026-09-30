import type { Page } from "@playwright/test";
import { test, expect } from "./fixtures";

/** The dashboard's steps and weight tiles (W1.7) against the gallery's
 *  "Dashboard tiles" section (EN, 1440 wide): what the steps subline says
 *  under and over the goal, the ✓ staying in steps purple, the weekly-pace
 *  chip and goal line on the weight tile, and the empty state. */

function tile(page: Page, name: string) {
  return page.locator(`#dashboard-tiles [data-state="${name}"]`);
}

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Dashboard tiles", exact: true }).scrollIntoViewIfNeeded();
});

test("steps under the goal: what's left and the walking time, goal in the header", async ({ page }) => {
  const t = tile(page, "steps-under");
  await expect(t.getByText("6,412")).toBeVisible();
  await expect(t.getByText("goal 9,000")).toBeVisible();
  await expect(t.getByText("2,588 to go · about 25 min walk")).toBeVisible();
  await expect(t.getByTestId("steps-reached")).toHaveCount(0);
});

test("steps at the goal: a check and 'Goal reached' in the same purple as the bar", async ({ page }) => {
  const t = tile(page, "steps-reached");
  const reached = t.getByTestId("steps-reached");
  await expect(reached).toHaveText("check_circleGoal reached");
  const colours = await t.evaluate((el, testId) => {
    const text = el.querySelector(`[data-testid="${testId}"]`) as HTMLElement;
    // the bar's fill is the only element whose background is painted with the metric colour
    const fill = [...el.querySelectorAll<HTMLElement>("div")].find((d) => d.style.background.includes("--metric-steps"));
    return { text: getComputedStyle(text).color, bar: fill ? getComputedStyle(fill).backgroundColor : null };
  }, "steps-reached");
  expect(colours.bar).not.toBeNull();
  expect(colours.text).toBe(colours.bar);
});

test("weight with a goal: relative date, value, weekly pace chip and what's left", async ({ page }) => {
  const t = tile(page, "weight-losing");
  await expect(t.getByText("today", { exact: true })).toBeVisible();
  await expect(t.getByText("69.6")).toBeVisible();
  await expect(t.getByText("−0.4 kg / week")).toBeVisible();
  await expect(t.getByText("Goal 65 kg · 4.6 kg to go")).toBeVisible();
});

test("the weight tile draws a trend line when it has history — and none without", async ({ page }) => {
  await expect(tile(page, "weight-losing").getByTestId("trend-spark")).toBeVisible();
  await expect(tile(page, "weight-gaining-no-goal").getByTestId("trend-spark")).toHaveCount(0);
});

test("weight without a goal: a gaining pace chip, yesterday, no goal line", async ({ page }) => {
  const t = tile(page, "weight-gaining-no-goal");
  await expect(t.getByText("yesterday", { exact: true })).toBeVisible();
  await expect(t.getByText("+0.3 kg / week")).toBeVisible();
  await expect(t.getByText(/^Goal /)).toHaveCount(0);
});

test("weight at the goal says so, and with no pace shows no chip", async ({ page }) => {
  const t = tile(page, "weight-reached");
  await expect(t.getByText("Goal reached")).toBeVisible();
  await expect(t.getByText(/kg \/ week/)).toHaveCount(0);
});

test("a fresh account gets an empty state with a log button, not a zero", async ({ page }) => {
  const t = tile(page, "weight-empty");
  await expect(t.getByText("Weigh yourself")).toBeVisible();
  await expect(t.getByRole("button", { name: "Log weight" })).toBeVisible();
  await expect(t.getByText("0.0")).toHaveCount(0);
});

test("the weekly-pace chip shortens below 1280 (tile copy shortens at 1024)", async ({ page }) => {
  await page.setViewportSize({ width: 1024, height: 768 });
  await page.reload();
  await expect(tile(page, "weight-losing").getByText("−0.4 kg/wk")).toBeVisible();
  await expect(tile(page, "steps-under").getByText("2,588 to 9,000")).toBeVisible();
});
