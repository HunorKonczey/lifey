import type { Page } from "@playwright/test";
import { test, expect } from "./fixtures";

/** The add-food dialog's preview pane (W2.6) against the gallery's section
 *  (EN): quantity and chips, the four macro tiles, "left after this", the meal
 *  type that names the submit, recipes by servings, and cancel. The day is the
 *  canvas' 1 041 of 1 900 kcal and 68 of 120 g protein eaten. */

const dialog = (page: Page) => page.locator("#lifey-overlay-root").getByRole("dialog", { name: "Add food" });
const tile = (page: Page, key: string) => dialog(page).locator(`[data-tile="${key}"]`);

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Add food dialog", exact: true }).scrollIntoViewIfNeeded();
  await page.getByTestId("open-add-food").click();
  await expect(dialog(page)).toBeVisible();
});

test("the highlighted food starts at its last logged quantity, with the macros for it", async ({ page }) => {
  await page.keyboard.type("görög");
  await expect(page.getByTestId("preview-title")).toHaveText("Görög joghurt 2%");
  await expect(dialog(page).getByRole("textbox", { name: "Quantity" })).toHaveValue("150");
  await expect(tile(page, "kcal")).toContainText("110"); // 73 kcal / 100 g × 1.5
  await expect(tile(page, "protein")).toContainText("14.9 g");
  await expect(tile(page, "carbs")).toContainText("5.9 g");
  await expect(tile(page, "fat")).toContainText("3 g");
});

test("quantity chips: '100 g' and the last used amount; a click sets the quantity and the macros follow", async ({ page }) => {
  await page.keyboard.type("görög");
  const chips = dialog(page).getByRole("group", { name: "Quick quantities" }).getByRole("button");
  await expect(chips).toHaveText(["100 g", "150 g"]);
  await expect(chips.nth(1)).toHaveAttribute("aria-pressed", "true");
  await chips.nth(0).click();
  await expect(dialog(page).getByRole("textbox", { name: "Quantity" })).toHaveValue("100");
  await expect(tile(page, "kcal")).toContainText("73");
});

test("typing a quantity updates the preview live, and a decimal comma or point round-trips to one decimal", async ({ page }) => {
  await page.keyboard.type("kefir");
  await page.keyboard.press("Tab");
  await page.keyboard.type("166.7");
  await expect(tile(page, "kcal")).toContainText("87"); // 52 × 1.667
  await page.keyboard.press("Tab"); // blur commits and formats
  await expect(dialog(page).getByRole("textbox", { name: "Quantity" })).toHaveValue("166.7");
});

test("'left after this' subtracts the entry from the day: 1 041 + 110 of 1 900 kcal, protein of 120 g", async ({ page }) => {
  await page.keyboard.type("görög");
  const remaining = dialog(page).getByTestId("preview-remaining");
  await expect(remaining).toContainText("750 kcal left after this"); // 1 900 − 1 041 − 109.5
  await expect(remaining).toContainText("protein 37 g to go");
});

test("a big enough portion flips the line to 'over', in words", async ({ page }) => {
  await page.keyboard.type("joghurt 10");
  await page.keyboard.press("Tab");
  await page.keyboard.type("900"); // 133 kcal / 100 g × 9
  await expect(dialog(page).getByTestId("preview-remaining")).toContainText("over after this");
});

test("the meal type starts at the caller's and renames the submit button", async ({ page }) => {
  await expect(dialog(page).getByRole("button", { name: "Add to dinner" })).toBeVisible();
  await dialog(page).getByRole("radio", { name: "Breakfast" }).click();
  await expect(dialog(page).getByRole("button", { name: "Add to breakfast" })).toBeVisible();
  await dialog(page).getByRole("radio", { name: "Snack" }).click();
  await expect(dialog(page).getByRole("button", { name: "Add to snack" })).toBeVisible();
});

test("submitting sends the row, the quantity and the chosen meal", async ({ page }) => {
  await page.keyboard.type("kefir");
  await dialog(page).getByRole("radio", { name: "Lunch" }).click();
  await dialog(page).getByRole("button", { name: "Add to lunch" }).click();
  await expect(dialog(page)).toHaveCount(0);
  await expect(page.getByTestId("added-log")).toHaveText("Added: Kefir 200 g LUNCH");
});

test("a recipe is logged by servings: servings unit, 0.5 / 1 / 2 chips, kcal per serving", async ({ page }) => {
  await dialog(page).getByRole("button", { name: "Recipes" }).click();
  await expect(page.getByTestId("preview-title")).toHaveText("Joghurtos zabkása");
  await expect(dialog(page).getByRole("textbox", { name: "Quantity" })).toHaveValue("1");
  await expect(dialog(page).getByText("servings", { exact: true })).toBeVisible();
  await expect(dialog(page).getByRole("group", { name: "Quick quantities" }).getByRole("button")).toHaveText(["0.5 servings", "1 serving", "2 servings"]);
  await expect(tile(page, "kcal")).toContainText("412");
  await dialog(page).getByRole("button", { name: "2 servings" }).click();
  await expect(tile(page, "kcal")).toContainText("824");
});

test("Cancel closes without adding", async ({ page }) => {
  await dialog(page).getByRole("button", { name: "Cancel" }).click();
  await expect(dialog(page)).toHaveCount(0);
  await expect(page.getByTestId("added-log")).toHaveText("Added: —");
});

test("an empty result leaves the right pane asking for a pick, with submit unavailable", async ({ page }) => {
  await page.keyboard.type("pizza");
  await expect(dialog(page).getByText("Search and pick a food on the left.")).toBeVisible();
  await expect(dialog(page).getByRole("button", { name: /^Add to/ })).toHaveCount(0);
});
