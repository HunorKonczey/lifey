import { test, expect } from "@playwright/test";

/** Toast (D-W0.14) against the gallery's "Toast" section: one at a time,
 *  the sticky error variant with its own close button, and the undo
 *  pattern it drives for D-W0.16 (delete → Undo restores the row). */

test.beforeEach(async ({ page }) => {
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Toast", exact: true }).scrollIntoViewIfNeeded();
});

test("shows the message and auto-dismisses a non-sticky toast", async ({ page }) => {
  await page.getByRole("button", { name: "Show default" }).click();
  const toast = page.getByRole("status");
  await expect(toast).toHaveText(/Saved/);
});

test("only one toast is visible at a time — a new one replaces the old", async ({ page }) => {
  await page.getByRole("button", { name: "Show default" }).click();
  await expect(page.getByRole("status")).toHaveText(/Saved/);
  await page.getByRole("button", { name: "Show success" }).click();
  await expect(page.getByRole("status")).toHaveCount(1);
  await expect(page.getByRole("status")).toHaveText(/Workout logged/);
});

test("the error variant is sticky, assertive, and has its own close button", async ({ page }) => {
  await page.getByRole("button", { name: "Show error" }).click();
  const toast = page.getByRole("status");
  await expect(toast).toHaveAttribute("aria-live", "assertive");
  const closeButton = toast.getByRole("button", { name: "Close" });
  await expect(closeButton).toBeVisible();
  // Still there well past the 6s window a non-sticky toast would use.
  await page.waitForTimeout(1000);
  await expect(toast).toBeVisible();
  await closeButton.click();
  await expect(page.getByRole("status")).toHaveCount(0);
});

test("deleting an item shows an undo toast; Undo restores the row without deleting it", async ({ page }) => {
  // exact: true — the undo toast's own text ('"Chicken breast" deleted')
  // otherwise still matches as a substring once the row itself is gone.
  const row = page.getByText("Chicken breast", { exact: true });
  await expect(row).toBeVisible();
  await page.getByRole("button", { name: "Delete Chicken breast" }).click();
  await expect(row).toHaveCount(0);
  const toast = page.getByRole("status");
  await expect(toast).toHaveText(/Chicken breast.*deleted/);
  await toast.getByRole("button", { name: "Undo" }).click();
  await expect(row).toBeVisible();
  await expect(page.getByRole("status")).toHaveCount(0);
});

test("an undo toast commits (disappears for good) once its window elapses", async ({ page }) => {
  await page.getByRole("button", { name: "Delete Chicken breast" }).click();
  await expect(page.getByRole("status")).toBeVisible();
  await expect(page.getByRole("status")).toHaveCount(0, { timeout: 7000 });
  await expect(page.getByText("Chicken breast", { exact: true })).toHaveCount(0);
});
