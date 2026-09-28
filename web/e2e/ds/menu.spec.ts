import { test, expect } from "@playwright/test";

/** Popover/Menu/RowMenuButton (D-W0.11) against the gallery's
 *  "Popover & menu" section: arrow navigation, typeahead, Esc, focus
 *  return, and the flip near a viewport edge. */

test.beforeEach(async ({ page }) => {
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Popover & menu", exact: true }).scrollIntoViewIfNeeded();
});

test("opens on click and focuses the first item", async ({ page }) => {
  await page.getByRole("button", { name: "Open menu" }).click();
  const menu = page.getByRole("menu");
  await expect(menu).toBeVisible();
  await expect(page.getByRole("menuitem", { name: "Edit" })).toBeFocused();
});

test("arrow keys move the active item", async ({ page }) => {
  await page.getByRole("button", { name: "Open menu" }).click();
  await page.keyboard.press("ArrowDown");
  await expect(page.getByRole("menuitem", { name: "Duplicate" })).toBeFocused();
  await page.keyboard.press("ArrowDown");
  await expect(page.getByRole("menuitem", { name: /Delete/ })).toBeFocused();
  // Wraps back to the first item.
  await page.keyboard.press("ArrowDown");
  await expect(page.getByRole("menuitem", { name: "Edit" })).toBeFocused();
});

test("typeahead jumps to the item starting with the typed letter", async ({ page }) => {
  await page.getByRole("button", { name: "Open menu" }).click();
  await page.keyboard.press("d"); // "Duplicate" and "Delete" both start with D; first match wins
  await expect(page.getByRole("menuitem", { name: "Duplicate" })).toBeFocused();
});

test("the destructive item is last and its label ends with an ellipsis", async ({ page }) => {
  await page.getByRole("button", { name: "Open menu" }).click();
  const items = page.getByRole("menuitem");
  await expect(items.last()).toHaveText(/Delete…/);
});

test("Enter selects the active item and closes the menu", async ({ page }) => {
  await page.getByRole("button", { name: "Open menu" }).click();
  await page.keyboard.press("Enter");
  await expect(page.getByRole("menu")).toHaveCount(0);
  await expect(page.getByText("Last action: Edit")).toBeVisible();
});

test("Esc closes the menu and returns focus to the trigger", async ({ page }) => {
  const trigger = page.getByRole("button", { name: "Open menu" });
  await trigger.click();
  await page.keyboard.press("Escape");
  await expect(page.getByRole("menu")).toHaveCount(0);
  await expect(trigger).toBeFocused();
});

test("an outside click closes the menu", async ({ page }) => {
  await page.getByRole("button", { name: "Open menu" }).click();
  await page.mouse.click(10, 10);
  await expect(page.getByRole("menu")).toHaveCount(0);
});

test("Shift+F10 opens the row menu", async ({ page }) => {
  const rowMenuButton = page.getByRole("button", { name: "More actions" });
  await rowMenuButton.focus();
  await page.keyboard.press("Shift+F10");
  await expect(page.getByRole("menuitem", { name: "View" })).toBeVisible();
});

test("the menu flips above near the bottom edge of the viewport", async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 500 });
  const rowMenuButton = page.getByRole("button", { name: "More actions" });
  await rowMenuButton.scrollIntoViewIfNeeded();
  const triggerBox = await rowMenuButton.boundingBox();
  await rowMenuButton.click();
  const menu = page.getByRole("menu").locator("..");
  const menuBox = await menu.boundingBox();
  expect(menuBox!.y).toBeLessThan(triggerBox!.y);
});
