import { test, expect } from "./fixtures";

/** DS-02's date stepper (D-W0.21) against the gallery's standalone demo:
 *  next disabled on today, prev/next/T keyboard shortcuts, and the
 *  calendar popover opening from the pill. */

test.beforeEach(async ({ page }) => {
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Date stepper", exact: true }).scrollIntoViewIfNeeded();
});

test("next day is disabled while on today", async ({ page }) => {
  await expect(page.getByRole("button", { name: "Next day" })).toBeDisabled();
});

test("the previous-day arrow shows a Back to today chip and re-enables next", async ({ page }) => {
  await page.getByRole("button", { name: "Previous day" }).click();
  await expect(page.getByRole("button", { name: "Back to today" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Next day" })).toBeEnabled();
});

test("pressing T jumps back to today", async ({ page }) => {
  await page.getByRole("button", { name: "Previous day" }).click();
  await page.keyboard.press("t");
  await expect(page.getByRole("button", { name: "Back to today" })).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Next day" })).toBeDisabled();
});

test("clicking the pill opens the calendar popover", async ({ page }) => {
  await page.getByRole("button", { name: /^Today/ }).click();
  // Portals into the shared overlay root — the always-visible "Date picker"
  // gallery section has its own, separate calendar with the same month label.
  const popover = page.locator("#lifey-overlay-root");
  await expect(popover.getByRole("dialog")).toBeVisible();
  await expect(popover.getByRole("grid")).toBeVisible();
});

test("at 390 the Back to today chip is an icon, so the whole stepper fits the screen", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.getByRole("button", { name: "HU", exact: true }).click(); // the longest date strings
  await page.getByRole("button", { name: "Előző nap" }).click();
  const chip = page.getByRole("button", { name: "Vissza a mai napra" });
  await expect(chip).toBeVisible();
  expect((await chip.boundingBox())!.width).toBeLessThanOrEqual(40);
  const next = (await page.getByRole("button", { name: "Következő nap" }).boundingBox())!;
  expect(next.x + next.width).toBeLessThanOrEqual(390);
});
