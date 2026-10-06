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
  await page.evaluate(() => window.localStorage.removeItem("lifey.addFood.offSearch")); // each test starts with the box off
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
  await page.keyboard.press("ArrowDown"); // the first two rows are "Joghurt 10%" and the recipe; the third is a food
  await expect(options(page).nth(2)).toHaveAttribute("aria-selected", "true");
  const picked = (await options(page).nth(2).innerText()).split("\n")[0];

  await page.keyboard.press("Tab");
  await expect(dialog(page).getByRole("textbox", { name: "Quantity" })).toBeFocused();
  await page.keyboard.type("150");
  await page.keyboard.press("Enter");

  await expect(page.getByTestId("added-log")).toHaveText(`Added: ${picked} 150 g DINNER`);
  // The dialog stays for the next one, with a clean, focused search.
  await expect(dialog(page)).toBeVisible();
  await expect(dialog(page).getByRole("combobox")).toHaveValue("");
  await expect(dialog(page).getByRole("combobox")).toBeFocused();
});

test("Enter in the search field adds the active row with the preview's quantity", async ({ page }) => {
  await page.keyboard.type("kefir");
  await page.keyboard.press("Enter");
  await expect(page.getByTestId("added-log")).toHaveText("Added: Kefir 200 g DINNER"); // Kefir was last logged at 200 g
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

// ── "Search OpenFoodFacts too" (docs/84): the gallery replaces the backend with canned answers ──

const offBox = (page: Page) => dialog(page).getByRole("checkbox", { name: "Search OpenFoodFacts too" });
const offSection = (page: Page) => dialog(page).getByTestId("off-section");
const offRequests = (page: Page) => page.getByTestId("off-requests");

test("the OpenFoodFacts box is off by default: typing makes no request and shows no section", async ({ page }) => {
  await expect(offBox(page)).toHaveAttribute("aria-checked", "false");
  await page.keyboard.type("csirkemell");
  await expect(offSection(page)).toHaveCount(0);
  await expect(offRequests(page)).toHaveText("OpenFoodFacts requests: 0");
});

test("ticked: a 'From OpenFoodFacts' section under the own results, with name, brand, OFF tag and kcal / 100 g", async ({ page }) => {
  await offBox(page).click();
  await page.keyboard.type("csirkemell");

  await expect(offSection(page).getByText("From OpenFoodFacts")).toBeVisible();
  const rows = offSection(page).getByRole("option");
  await expect(rows).toHaveCount(3);
  await expect(rows.nth(0)).toContainText("Csirkemell");
  await expect(rows.nth(0)).toContainText("Pikok");
  await expect(rows.nth(0)).toContainText("OFF");
  await expect(rows.nth(0)).toContainText("110 kcal / 100 g");
  await expect(rows.nth(2)).toContainText("Nádudvari");
  await expect(offRequests(page)).toHaveText("OpenFoodFacts requests: 1");
});

test("the own results and their count are not touched by OpenFoodFacts rows", async ({ page }) => {
  await offBox(page).click();
  await page.keyboard.type("joghurt");
  await expect(dialog(page).getByText("4 results")).toBeVisible();
  // none of the fixture's OpenFoodFacts products matches "joghurt": the section says so, the own rows stay
  await expect(offSection(page)).toContainText("Nothing found on OpenFoodFacts.");
  await expect(dialog(page).getByRole("option")).toHaveCount(4);
});

test("own results empty but OpenFoodFacts has some: both the empty message and the section show", async ({ page }) => {
  await offBox(page).click();
  await page.keyboard.type("csirkemell");
  await expect(dialog(page).getByText("Nothing matches that.")).toBeVisible();
  await expect(offSection(page).getByRole("option")).toHaveCount(3);
});

test("↓ walks from the last own row into the OpenFoodFacts rows, and the preview shows its macros (submit waits for the next step)", async ({ page }) => {
  await offBox(page).click();
  await page.keyboard.type("túró");
  await expect(offSection(page).getByRole("option")).toHaveCount(1); // the answer has arrived
  // no own row, so ↓ must land on the FIRST OpenFoodFacts row, not skip it
  await page.keyboard.press("ArrowDown");
  await expect(offSection(page).getByRole("option").nth(0)).toHaveAttribute("aria-selected", "true");
  await expect(page.getByTestId("preview-title")).toHaveText("Túró Rudi");
  await expect(dialog(page).getByText("OpenFoodFacts · 400 kcal / 100 g")).toBeVisible();
  await expect(dialog(page).getByTestId("preview-macros").locator('[data-tile="kcal"]')).toContainText("400");
  await expect(dialog(page).getByRole("button", { name: /^Add to/ })).toBeDisabled();
});

test("↓ from the last own row continues into the OpenFoodFacts rows, and ↑ goes back", async ({ page }) => {
  await offBox(page).click();
  await page.keyboard.type("skyr"); // one own row (Skyr natúr) and one OpenFoodFacts row
  await expect(options(page)).toHaveCount(2);
  await expect(options(page).nth(0)).toHaveAttribute("aria-selected", "true");

  await page.keyboard.press("ArrowDown");
  await expect(options(page).nth(1)).toHaveAttribute("aria-selected", "true");
  await expect(offSection(page).getByRole("option")).toHaveAttribute("aria-selected", "true");
  await expect(page.getByTestId("preview-title")).toHaveText("Skyr vaníliás");

  await page.keyboard.press("ArrowDown"); // already last: stays put
  await expect(options(page).nth(1)).toHaveAttribute("aria-selected", "true");
  await page.keyboard.press("ArrowUp");
  await expect(options(page).nth(0)).toHaveAttribute("aria-selected", "true");
  await expect(page.getByTestId("preview-title")).toHaveText("Skyr natúr");
});

test("a row's source line names the brand, or OpenFoodFacts when there is none", async ({ page }) => {
  await offBox(page).click();
  await page.keyboard.type("túró");
  await expect(offSection(page).getByRole("option").nth(0)).toContainText("OpenFoodFacts"); // no brand
});

test("the English fallback, unavailable and rate-limited each get their one line", async ({ page }) => {
  await offBox(page).click();
  await page.keyboard.type("pumpkin");
  await expect(offSection(page).getByRole("note")).toHaveText("Nothing found among products sold in Hungary — showing English-language results from everywhere.");
  await expect(offSection(page).getByRole("option")).toHaveCount(1);

  await dialog(page).getByRole("combobox").fill("unavail");
  await expect(offSection(page).getByRole("note")).toHaveText("OpenFoodFacts isn't answering right now.");
  await expect(offSection(page).getByRole("option")).toHaveCount(0);

  await dialog(page).getByRole("combobox").fill("limited");
  await expect(offSection(page).getByRole("note")).toHaveText("Too many searches — try again in a minute.");

  await dialog(page).getByRole("combobox").fill("boom");
  await expect(offSection(page).getByRole("note")).toHaveText("OpenFoodFacts isn't answering right now.");
});

test("while OpenFoodFacts is still answering, one 'Searching…' line, not a spinner over the list", async ({ page }) => {
  await offBox(page).click();
  await page.keyboard.type("slowpoke");
  await expect(offSection(page).getByRole("status")).toHaveText("Searching OpenFoodFacts…");
});

test("under 3 letters the section asks for more and makes no request", async ({ page }) => {
  await offBox(page).click();
  await page.keyboard.type("cs");
  await expect(offSection(page)).toContainText("Type at least 3 letters to search OpenFoodFacts.");
  await expect(offRequests(page)).toHaveText("OpenFoodFacts requests: 0");
  await page.keyboard.type("i");
  await expect(offRequests(page)).toHaveText("OpenFoodFacts requests: 1");
});

test("unticking removes the section; the choice is remembered on this device", async ({ page }) => {
  await offBox(page).click();
  await page.keyboard.type("csirkemell");
  await expect(offSection(page)).toBeVisible();
  await offBox(page).click();
  await expect(offSection(page)).toHaveCount(0);
  await offBox(page).click();

  await page.reload();
  await page.getByRole("heading", { name: "Add food dialog", exact: true }).scrollIntoViewIfNeeded();
  await page.getByTestId("open-add-food").click();
  await expect(offBox(page)).toHaveAttribute("aria-checked", "true");
});

test("on a phone the checkbox is in the sheet and nothing scrolls sideways", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await offBox(page).scrollIntoViewIfNeeded();
  await expect(offBox(page)).toBeVisible();
  await offBox(page).click();
  await page.keyboard.type("csirkemell");
  await expect(offSection(page).getByRole("option").first()).toBeVisible();
  const overflow = await dialog(page).evaluate((el) => el.scrollWidth - el.clientWidth);
  expect(overflow).toBeLessThanOrEqual(0);
});
