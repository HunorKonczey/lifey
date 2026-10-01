import type { Page } from "@playwright/test";
import { test, expect } from "./fixtures";

/** The dashboard's recent-workouts list (W1.10) against the gallery's
 *  section (EN): rows with icon, name, meta and relative date; the PR chip only
 *  on the row that set one; a label instead of a raw activity key; three rows
 *  on a phone; and the empty prompt. */

function list(page: Page, name: "rows" | "empty") {
  return page.locator(`#recent-workouts [data-state="${name}"]`);
}

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Recent workouts list", exact: true }).scrollIntoViewIfNeeded();
});

test("each row shows its name, one meta line and a relative date; 'All' goes to the workouts page", async ({ page }) => {
  const l = list(page, "rows");
  await expect(l.getByRole("listitem")).toHaveCount(4);
  const first = l.getByRole("listitem").first();
  await expect(first.getByText("Leg + core")).toBeVisible();
  await expect(first.getByText("52 min · 6,240 kg · 18 sets")).toBeVisible();
  await expect(first.getByText("yesterday")).toBeVisible();
  await expect(l.getByRole("link", { name: "All" })).toHaveAttribute("href", "/workouts");
});

test("the PR chip appears only on the session that set a record", async ({ page }) => {
  const l = list(page, "rows");
  await expect(l.getByText("PR", { exact: true })).toHaveCount(1);
  await expect(l.getByRole("listitem").first().getByText("PR", { exact: true })).toBeVisible();
});

test("cardio rows read as words and the tile tint differs from strength", async ({ page }) => {
  const l = list(page, "rows");
  await expect(l.getByText("Running")).toBeVisible();
  await expect(l.getByText(/(RUNNING|WALKING|CYCLING|HIKING|INDOOR_BIKE|OTHER_CARDIO)/)).toHaveCount(0);
  const bg = (i: number) =>
    l.getByRole("listitem").nth(i).locator("span").first().evaluate((el) => getComputedStyle(el).backgroundColor);
  expect(await bg(0)).not.toBe(await bg(1)); // strength (primary tint) vs cardio (heart tint)
  expect(await bg(0)).toBe(await bg(2)); // two strength rows share one
});

test("a row is a button that can be activated from the keyboard", async ({ page }) => {
  const row = list(page, "rows").getByRole("button", { name: /Leg \+ core/ });
  await row.focus();
  await expect(row).toBeFocused();
});

test("on a phone the fourth row drops", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.reload();
  await expect(list(page, "rows").getByRole("listitem").locator("visible=true")).toHaveCount(3);
});

test("an account with no sessions gets a prompt, not an empty card", async ({ page }) => {
  const l = list(page, "empty");
  await expect(l.getByText("No workouts yet")).toBeVisible();
  await expect(l.getByRole("button", { name: "Start workout" })).toBeVisible();
  await expect(l.getByRole("listitem")).toHaveCount(0);
});
