import type { Page } from "@playwright/test";
import { test, expect } from "./fixtures";

/** The add-food dialog's search pane (W2.5) against the gallery's shell with a
 *  stub preview (EN): a keyboard-only flow (type → ↓ → Tab → quantity → Enter),
 *  filters, ranking, the active-row marker and the empty-result shortcut. */

const dialog = (page: Page) => page.locator("#lifey-overlay-root").getByRole("dialog", { name: "Add food" });
const options = (page: Page) => dialog(page).getByRole("option");

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Add food dialog", exact: true }).scrollIntoViewIfNeeded();
  await page.getByTestId("open-add-food").click();
  await expect(dialog(page)).toBeVisible();
});

test("opens with the search field focused and the recent foods first", async ({ page }) => {
  await expect(dialog(page).getByRole("combobox", { name: "Search foods and recipes" })).toBeFocused();
  // Kefir was logged an hour ago, Greek yoghurt yesterday; then the rest alphabetically
  await expect(options(page).nth(0)).toContainText("Kefir");
  await expect(options(page).nth(1)).toContainText("Görög joghurt 2%");
  await expect(dialog(page).getByText("7 results")).toBeVisible();
});

test("a result row has a source line and kcal per 100 g; a recipe says 'Recipe · 1 serving … kcal'", async ({ page }) => {
  const kefir = options(page).filter({ hasText: "Kefir" });
  await expect(kefir).toContainText("Own · last");
  await expect(kefir).toContainText("52 kcal / 100 g");
  const recipe = options(page).filter({ hasText: "Joghurtos zabkása" });
  await expect(recipe).toContainText("Recipe · 1 serving 412 kcal");
});

test("names that start with the query outrank names that only contain it", async ({ page }) => {
  await page.keyboard.type("joghurt");
  await expect(options(page).nth(0)).toContainText(/Joghurt 10%|Joghurtos zabkása/);
  await expect(options(page).nth(1)).toContainText(/Joghurt 10%|Joghurtos zabkása/);
  await expect(dialog(page).getByText("4 results")).toBeVisible();
});

test("keyboard only: type, ↓, Tab to the quantity, type 150, Enter adds exactly that row", async ({ page }) => {
  await page.keyboard.type("joghurt");
  const first = options(page).nth(0);
  await expect(first).toHaveAttribute("aria-selected", "true");
  await page.keyboard.press("ArrowDown");
  await expect(options(page).nth(1)).toHaveAttribute("aria-selected", "true");
  await expect(first).toHaveAttribute("aria-selected", "false");
  const picked = (await options(page).nth(1).innerText()).split("\n")[0];

  await page.keyboard.press("Tab");
  await expect(dialog(page).getByRole("textbox", { name: "Quantity (g)" })).toBeFocused();
  await page.keyboard.press("Control+a");
  await page.keyboard.type("150");
  await page.keyboard.press("Enter");

  await expect(dialog(page)).toHaveCount(0);
  await expect(page.getByTestId("added-log")).toHaveText(`Added: ${picked} 150 g`);
});

test("Enter in the search field adds the active row with the preview's quantity", async ({ page }) => {
  await page.keyboard.type("kefir");
  await page.keyboard.press("Enter");
  await expect(page.getByTestId("added-log")).toHaveText("Added: Kefir 100 g");
});

test("the active row carries a primary marker bar and the preview follows it", async ({ page }) => {
  await page.keyboard.press("ArrowDown");
  await expect(page.getByTestId("preview-title")).toHaveText("Görög joghurt 2%");
  await expect(options(page).nth(1).locator("span[aria-hidden]").first()).toBeVisible();
});

test("↑ at the top and ↓ at the bottom stay put instead of wrapping", async ({ page }) => {
  await page.keyboard.press("ArrowUp");
  await expect(options(page).nth(0)).toHaveAttribute("aria-selected", "true");
  for (let i = 0; i < 12; i++) await page.keyboard.press("ArrowDown");
  await expect(options(page).last()).toHaveAttribute("aria-selected", "true");
});

test("filters: Recipes shows recipes only, Favourites the favourite recipes, Recent what was logged", async ({ page }) => {
  await dialog(page).getByRole("button", { name: "Recipes" }).click();
  await expect(options(page)).toHaveCount(1);
  await dialog(page).getByRole("button", { name: "Favourites" }).click();
  await expect(options(page)).toHaveCount(1);
  await dialog(page).getByRole("button", { name: "Recent" }).click();
  await expect(options(page)).toHaveCount(2);
  await dialog(page).getByRole("button", { name: "My foods" }).click();
  await expect(options(page)).toHaveCount(6);
  await expect(dialog(page).getByRole("button", { name: "My foods" })).toHaveAttribute("aria-pressed", "true");
});

test("an empty result offers to create the food under the typed name", async ({ page }) => {
  await page.keyboard.type("pizza");
  await expect(options(page)).toHaveCount(0);
  await dialog(page).getByRole("button", { name: "Create a new food “pizza”" }).click();
  await expect(page.getByTestId("created-log")).toHaveText("Create: pizza");
});

test("Escape closes the dialog", async ({ page }) => {
  await page.keyboard.press("Escape");
  await expect(dialog(page)).toHaveCount(0);
});
