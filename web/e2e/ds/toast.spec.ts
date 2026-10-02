import type { Page } from "@playwright/test";
import { test, expect } from "./fixtures";

/** Toast (D-W0.14) against the gallery's "Toast" section: one at a time,
 *  the sticky error variant with its own close button, and the undo
 *  pattern it drives for D-W0.16 (delete → Undo restores the row). */

/** The gallery also holds dnd-kit and Recharts role=status live regions; target only the toast. */
const toastLocator = (page: Page) => page.locator('[role="status"].pointer-events-auto');

test.beforeEach(async ({ page }) => {
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Toast", exact: true }).scrollIntoViewIfNeeded();
});

test("shows the message and auto-dismisses a non-sticky toast", async ({ page }) => {
  await page.getByRole("button", { name: "Show default" }).click();
  const toast = toastLocator(page);
  await expect(toast).toHaveText(/Saved/);
});

test("only one toast is visible at a time — a new one replaces the old", async ({ page }) => {
  await page.getByRole("button", { name: "Show default" }).click();
  await expect(toastLocator(page)).toHaveText(/Saved/);
  await page.getByRole("button", { name: "Show success" }).click();
  await expect(toastLocator(page)).toHaveCount(1);
  await expect(toastLocator(page)).toHaveText(/Workout logged/);
});

test("the error variant is sticky, assertive, and has its own close button", async ({ page }) => {
  await page.getByRole("button", { name: "Show error" }).click();
  const toast = toastLocator(page);
  await expect(toast).toHaveAttribute("aria-live", "assertive");
  const closeButton = toast.getByRole("button", { name: "Close" });
  await expect(closeButton).toBeVisible();
  // Still there well past the 6s window a non-sticky toast would use.
  await page.waitForTimeout(1000);
  await expect(toast).toBeVisible();
  await closeButton.click();
  await expect(toastLocator(page)).toHaveCount(0);
});

test("deleting an item shows an undo toast; Undo restores the row without deleting it", async ({ page }) => {
  // exact: true — the undo toast's own text ('"Draft report" deleted')
  // otherwise still matches as a substring once the row itself is gone.
  const row = page.getByText("Draft report", { exact: true });
  await expect(row).toBeVisible();
  await page.getByRole("button", { name: "Delete Draft report" }).click();
  await expect(row).toHaveCount(0);
  const toast = toastLocator(page);
  await expect(toast).toHaveText(/Draft report.*deleted/);
  await toast.getByRole("button", { name: "Undo" }).click();
  await expect(row).toBeVisible();
  await expect(toastLocator(page)).toHaveCount(0);
});

test("an undo toast commits (disappears for good) once its window elapses", async ({ page }) => {
  await page.getByRole("button", { name: "Delete Draft report" }).click();
  await expect(toastLocator(page)).toBeVisible();
  await expect(toastLocator(page)).toHaveCount(0, { timeout: 7000 });
  await expect(page.getByText("Draft report", { exact: true })).toHaveCount(0);
});
