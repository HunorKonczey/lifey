import type { Page } from "@playwright/test";
import { test, expect } from "./fixtures";

/** The dashboard's 7-day calories card (W1.8) against the gallery's "Week
 *  calories" section (EN): header statistics without today and without the
 *  unlogged day, the seven-bar chart with its goal line, and — at 1024 — a Y
 *  axis that isn't clipped by the card. */

function card(page: Page, name: "goal" | "no-goal") {
  return page.locator(`#week-calories [data-state="${name}"]`);
}

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Week calories", exact: true }).scrollIntoViewIfNeeded();
});

test("the header averages the logged complete days, counts within-goal of 6, and counts workouts", async ({ page }) => {
  const c = card(page, "goal");
  await expect(c.getByText("Last 7 days")).toBeVisible();
  // (1600 + 2100 + 1800 + 1700 + 1900) / 5 — not today's 400, not the unlogged day
  await expect(c.getByText("1,820 kcal")).toBeVisible();
  // 1600, 1800, 1700, 1900 within; 2100 over; 0 isn't logged
  await expect(c.getByText("4 / 6 days")).toBeVisible();
  await expect(c.getByText("workouts").locator("xpath=following-sibling::span")).toHaveText("2");
});

test("the chart has seven labelled columns, today spelled out, and a dashed goal line", async ({ page }) => {
  const c = card(page, "goal");
  const chart = c.getByRole("img", { name: "Calories over the last 7 days" });
  await expect(chart.locator(".recharts-xAxis .recharts-cartesian-axis-tick")).toHaveCount(7);
  // Recharts 3 paints axis labels as SVG <text> in its own layer, not inside
  // `.recharts-xAxis` — so match by tag + exact text over the whole chart.
  for (const label of ["Thu", "Fri", "Sat", "Sun", "Mon", "Tue", "Today"]) {
    await expect(chart.locator("text").filter({ hasText: new RegExp(`^${label}$`) })).toHaveCount(1);
  }
  await expect(chart.locator("text").filter({ hasText: "goal 1,900" })).toHaveCount(1);
  await expect(chart.locator(".recharts-reference-line line")).toHaveAttribute("stroke-dasharray", /\d/);
});

test("without a calorie goal: no within-goal stat and no goal line", async ({ page }) => {
  const c = card(page, "no-goal");
  await expect(c.getByText("within goal")).toHaveCount(0);
  await expect(c.locator(".recharts-reference-line")).toHaveCount(0);
  await expect(c.getByText("1,820 kcal")).toBeVisible();
});

test("today is an unfilled dashed outline", async ({ page }) => {
  const c = card(page, "goal");
  await expect(c.locator("rect[stroke-dasharray]").first()).toBeVisible();
});

test("at 1024 the Y axis labels stay inside the card", async ({ page }) => {
  await page.setViewportSize({ width: 1024, height: 768 });
  await page.reload();
  const c = card(page, "goal");
  await c.scrollIntoViewIfNeeded();
  const cardBox = (await c.getByTestId("week-calories").boundingBox())!;
  const yTicks = c.locator("text").filter({ hasText: /^(0|1\.1k|2\.1k)$/ });
  await expect(yTicks).toHaveCount(3);
  const ticks = await yTicks.all();
  for (const tick of ticks) {
    const box = (await tick.boundingBox())!;
    expect(box.x).toBeGreaterThanOrEqual(cardBox.x);
    expect(box.x + box.width).toBeLessThanOrEqual(cardBox.x + cardBox.width);
  }
});
