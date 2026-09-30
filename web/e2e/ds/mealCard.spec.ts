import type { Page } from "@playwright/test";
import { test, expect } from "./fixtures";

/** The meal card (W2.3) against the gallery's "Meal card" section (EN, 1440):
 *  header (type, time · count, kcal), item rows with always-visible macros,
 *  names that wrap instead of truncating, a row "⋯" that appears on focus,
 *  the recipe variant and the read-only card. */

function cards(page: Page, state: "editable" | "read-only") {
  return page.locator(`#meal-card [data-state="${state}"]`).getByTestId("meal-card");
}

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Meal card", exact: true }).scrollIntoViewIfNeeded();
});

test("the header shows the type, time · item count and the kcal total", async ({ page }) => {
  const breakfast = cards(page, "editable").nth(0);
  await expect(breakfast.getByRole("heading", { name: "Breakfast" })).toBeVisible();
  await expect(breakfast.getByText("7:15 AM · 3 items")).toBeVisible();
  await expect(breakfast.getByText("379 kcal").first()).toBeVisible();
});

test("a recipe meal is one row for the whole portion, labelled 'recipe'", async ({ page }) => {
  const lunch = cards(page, "editable").nth(1);
  await expect(lunch.getByText("12:30 PM · recipe")).toBeVisible();
  await expect(lunch.locator(".meal-item-row")).toHaveCount(1);
  await expect(lunch.getByText("Csirkés rizstál brokkolival")).toBeVisible();
  await expect(lunch.getByText("420 g")).toBeVisible(); // 150 + 180 + 90
});

test("each row shows grams only, and carbs and fat are always visible next to protein", async ({ page }) => {
  const row = cards(page, "editable").nth(0).locator(".meal-item-row").nth(1); // Greek yoghurt
  await expect(row.getByText("150 g", { exact: true })).toBeVisible();
  await expect(row.getByText("15 g", { exact: true })).toBeVisible(); // protein
  await expect(row.getByText("5 g", { exact: true })).toBeVisible(); // carbs (rounded, like the canvas rows)
  await expect(row.getByText("3 g", { exact: true })).toBeVisible(); // fat
  await expect(row.getByText("110")).toBeVisible();
  await expect(row.getByText(/1 pohár|1 glass/)).toHaveCount(0); // no household units (D-W0.19)
});

test("a very long food name wraps onto more lines instead of being cut off", async ({ page }) => {
  const name = cards(page, "editable").nth(0).getByText(/^Teljes kiőrlésű, magvas kenyér/);
  await expect(name).toBeVisible();
  const { height, lineHeight, overflow, textOverflow } = await name.evaluate((el) => {
    const cs = getComputedStyle(el);
    return {
      height: el.getBoundingClientRect().height,
      lineHeight: parseFloat(cs.lineHeight) || parseFloat(cs.fontSize) * 1.3,
      overflow: cs.overflow,
      textOverflow: cs.textOverflow,
    };
  });
  expect(height).toBeGreaterThan(lineHeight * 1.5); // at least two lines
  expect(textOverflow).not.toBe("ellipsis");
  expect(overflow).not.toBe("hidden");
});

test("the row '⋯' is hidden until hover or focus, and focusing it (keyboard) reveals it", async ({ page }) => {
  await page.mouse.move(0, 0);
  const row = cards(page, "editable").nth(0).locator(".meal-item-row").first();
  const more = row.getByRole("button", { name: "Item options" });
  const wrapper = more.locator("xpath=..");
  await expect(wrapper).toHaveCSS("opacity", "0");
  await more.focus();
  await expect(wrapper).toHaveCSS("opacity", "1");
  await page.keyboard.press("Enter");
  await expect(page.getByRole("menuitem", { name: "Edit" })).toBeVisible();
});

test("the header menu offers Edit, Duplicate and a destructive Delete last", async ({ page }) => {
  const card = cards(page, "editable").nth(0);
  await card.getByRole("button", { name: "Meal options" }).click();
  const items = page.getByRole("menuitem");
  await expect(items).toHaveText([/Edit/, /Duplicate/, /Delete…/]);
});

test("the read-only card draws no actions", async ({ page }) => {
  const card = cards(page, "read-only").first();
  await expect(card.getByRole("button")).toHaveCount(0);
  await expect(card.getByText("Zabpehely")).toBeVisible();
});

test("a food row's '⋯' deletes that food — Edit, then a destructive Delete", async ({ page }) => {
  const row = cards(page, "editable").nth(0).locator(".meal-item-row").nth(1);
  await row.getByRole("button", { name: "Item options" }).focus();
  await page.keyboard.press("Enter");
  await expect(page.getByRole("menuitem")).toHaveText([/Edit/, /Delete…/]);
  await page.getByRole("menuitem", { name: /Delete/ }).click();
  await expect(page.getByTestId("delete-log")).toHaveText("Delete requested: item:1:1");
});

test("a recipe row's '⋯' deletes the whole meal — it is one row for the portion", async ({ page }) => {
  const row = cards(page, "editable").nth(1).locator(".meal-item-row").first();
  await row.getByRole("button", { name: "Item options" }).focus();
  await page.keyboard.press("Enter");
  await page.getByRole("menuitem", { name: /Delete/ }).click();
  await expect(page.getByTestId("delete-log")).toHaveText("Delete requested: meal:2");
});
