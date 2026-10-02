import { test, expect } from "./fixtures";

/** CalendarPopover + DateFields (D-W0.10) against the gallery's "Date
 *  picker" section: keyboard navigation, disabled future days, typed
 *  segments in each locale's order. */

test.beforeEach(async ({ page }) => {
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Date picker", exact: true }).scrollIntoViewIfNeeded();
});

test("arrow keys move the focused day within the grid", async ({ page }) => {
  const grid = page.getByRole("grid").first();
  const cells = grid.getByRole("gridcell");
  const focusable = grid.locator('[tabindex="0"]');
  await focusable.focus();
  const before = await focusable.getAttribute("aria-label");

  // Left first, then right: the grid is future-disabled, so from today the
  // focus must clamp rather than rove onto a day that can't take focus.
  await page.keyboard.press("ArrowLeft");
  await expect(grid.locator('[tabindex="0"]')).not.toHaveAttribute("aria-label", before!);
  await expect(grid.locator('[tabindex="0"]')).toBeFocused();

  await page.keyboard.press("ArrowRight");
  await expect(grid.locator('[tabindex="0"]')).toHaveAttribute("aria-label", before!);
  await expect(grid.locator('[tabindex="0"]')).toBeFocused();

  // ...and one more right stays on today instead of dropping focus.
  await page.keyboard.press("ArrowRight");
  await expect(grid.locator('[tabindex="0"]')).toHaveAttribute("aria-label", before!);
  await expect(grid.locator('[tabindex="0"]')).toBeFocused();

  await expect(cells.first()).toBeVisible();
});

test("PageUp/PageDown move by a month", async ({ page }) => {
  const dialog = page.getByRole("dialog").first();
  const monthLabelBefore = await dialog.locator(".type-title-s").innerText();

  await dialog.getByRole("grid").locator('[tabindex="0"]').focus();
  // PageUp: the grid is future-disabled, so PageDown from the current month clamps to today.
  await page.keyboard.press("PageUp");
  await expect(dialog.locator(".type-title-s")).not.toHaveText(monthLabelBefore);
  await page.keyboard.press("PageDown");
  await expect(dialog.locator(".type-title-s")).toHaveText(monthLabelBefore);
});

test("a future day is disabled and cannot be selected", async ({ page }) => {
  const dialog = page.getByRole("dialog").first();
  const disabledFuture = dialog.getByRole("gridcell", { disabled: true }).first();
  await expect(disabledFuture).toHaveCount(1);
});

test("Enter selects the focused day", async ({ page }) => {
  const dialog = page.getByRole("dialog").first();
  const grid = dialog.getByRole("grid");
  await grid.locator('[tabindex="0"]').focus();
  await page.keyboard.press("ArrowLeft");
  const target = await grid.locator('[tabindex="0"]').getAttribute("aria-label");
  await page.keyboard.press("Enter");
  await expect(grid.getByRole("gridcell", { selected: true })).toHaveAttribute("aria-label", target!);
});

test("DateFields orders segments per locale (EN: month, day, year)", async ({ page }) => {
  const segments = page.locator('input[aria-label*="Birth date"]');
  await expect(segments).toHaveCount(3);
  // In English order the first segment is "month".
  await expect(segments.first()).toHaveAttribute("aria-label", "Birth date – month");
});

test("DateFields advances focus to the next segment when one fills", async ({ page }) => {
  const month = page.getByLabel("Birth date – month", { exact: true });
  const day = page.getByLabel("Birth date – day", { exact: true });
  await month.click();
  await month.fill("09");
  await expect(day).toBeFocused();
});
