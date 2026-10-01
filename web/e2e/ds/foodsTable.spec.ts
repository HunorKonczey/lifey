import type { Page } from "@playwright/test";
import { test, expect } from "./fixtures";

/** The foods table + editor panel (W2.10) against the gallery's section (EN, 1440; viewing Sep 27, 2026):
 *  every column sorts, `/` focuses the search, the row "⋯" (Edit / Duplicate / Log today / Delete…),
 *  the editor's Save that waits for a real change, and the macro line's info / warning tones. */

const section = (page: Page) => page.locator("#foods-table");
const table = (page: Page) => section(page).getByRole("table", { name: "Food list" });
const firstName = (page: Page) => table(page).locator("tbody tr").first().locator("td").first();
const header = (page: Page, name: string) => table(page).getByRole("columnheader", { name });
const editor = (page: Page) => page.getByTestId("food-editor");

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Foods table and editor", exact: true }).scrollIntoViewIfNeeded();
});

test("lists the foods with their metric-dotted headers and a count", async ({ page }) => {
  for (const name of ["Name", "kcal / 100 g", "Protein", "Carbs", "Fat", "Last used"]) {
    await expect(header(page, name)).toBeVisible();
  }
  await expect(section(page).getByText("18 foods", { exact: false })).toBeVisible();
  await expect(table(page).locator("tbody tr")).toHaveCount(15); // one page
});

test("'Last used' shows today's relative day, then a short date, and a dash for a never-logged food", async ({ page }) => {
  const row = (name: string) => table(page).locator("tbody tr").filter({ has: page.getByRole("cell", { name, exact: true }) });
  await expect(row("Zabpehely")).toContainText("today");
  await expect(row("Görög joghurt 2%")).toContainText("yesterday");
  await expect(row("Barna rizs")).toContainText("Sep 20");
  await expect(row("Alma")).toContainText("—");
});

test("every column sorts, ascending then descending", async ({ page }) => {
  const check = async (column: string, asc: string, desc: string) => {
    await header(page, column).click();
    await expect(firstName(page)).toHaveText(asc);
    await header(page, column).click();
    await expect(firstName(page)).toHaveText(desc);
  };
  await check("Name", "Alma", "Zabpehely");
  await check("kcal / 100 g", "Brokkoli", "Olívaolaj");
  await check("Protein", "Olívaolaj", "Csirkemell"); // 0 g first, 31 g last
  await check("Carbs", "Csirkemell", "Zabpehely"); // ties at 0 g keep the table's order; 58.7 g is the most
  await check("Fat", "Édesburgonya", "Olívaolaj"); // 0.1 g … 100 g
  await check("Last used", "Édesburgonya", "Zabpehely"); // never-logged first (in list order), today's food last when ascending
});

test("search matches ignoring accents and case, and says so when nothing matches", async ({ page }) => {
  // (The `/` shortcut is checked on the real page: the gallery's Shortcuts demo answers `/` too.)
  const search = section(page).getByPlaceholder("Search /");
  await search.fill("edes");
  await expect(table(page).locator("tbody tr")).toHaveCount(1);
  await expect(firstName(page)).toHaveText("Édesburgonya");
  await search.fill("nincs ilyen");
  await expect(section(page).getByText("No foods match")).toBeVisible();
});

test("the row '⋯' offers Edit, Duplicate, Log today and a destructive Delete… last", async ({ page }) => {
  await section(page).getByRole("button", { name: "Actions for Zabpehely" }).click();
  await expect(page.getByRole("menuitem")).toHaveText([/Edit/, /Duplicate/, /Log today/, /Delete…/]);
  await page.getByRole("menuitem", { name: /Log today/ }).click();
  await expect(page.getByTestId("foods-log")).toHaveText("Last action: log Zabpehely");
  await section(page).getByRole("button", { name: "Actions for Alma" }).click();
  await page.getByRole("menuitem", { name: /Delete/ }).click();
  await expect(page.getByTestId("foods-log")).toHaveText("Last action: delete Alma");
});

test("clicking a row opens its editor with the stored values; Save waits for a real change", async ({ page }) => {
  await table(page).getByRole("cell", { name: "Zabpehely", exact: true }).click();
  await expect(editor(page).getByRole("heading", { name: "Edit food" })).toBeVisible();
  await expect(editor(page).getByRole("textbox", { name: "Name" })).toHaveValue("Zabpehely");
  await expect(editor(page).getByRole("textbox", { name: "Protein" })).toHaveValue("13.5");
  await expect(editor(page).getByText("100 g")).toBeVisible();
  await expect(editor(page).getByRole("button", { name: "Save" })).toBeDisabled();
  await editor(page).getByRole("textbox", { name: "Name" }).fill("Zabpehely bio");
  await expect(editor(page).getByRole("button", { name: "Save" })).toBeEnabled();
  await editor(page).getByRole("button", { name: "Save" }).click();
  await expect(page.getByTestId("foods-log")).toHaveText("Last action: save Zabpehely bio|372|13.5|58.7|7");
  await expect(editor(page)).toHaveCount(0);
});

test("tabbing through untouched fields is not a change", async ({ page }) => {
  await table(page).getByRole("cell", { name: "Zabpehely", exact: true }).click();
  for (const name of ["Calories", "Protein", "Carbs", "Fat"]) {
    await editor(page).getByRole("textbox", { name }).focus();
    await editor(page).getByRole("textbox", { name }).blur();
  }
  await expect(editor(page).getByRole("button", { name: "Save" })).toBeDisabled();
});

test("the macro line: nothing when they add up, an info note for a small gap, a warning above 10 %", async ({ page }) => {
  const line = editor(page).getByTestId("macro-line");
  await table(page).getByRole("cell", { name: "Zabpehely", exact: true }).click(); // 4·13.5 + 4·58.7 + 9·7 = 351.8 vs 372 → 20 off
  await expect(line).toHaveAttribute("data-tone", "info");
  await expect(line).toContainText("The macros add up to 352 kcal — that is 20 kcal off.");
  await table(page).getByRole("cell", { name: "Kefir", exact: true }).click(); // 71.8 → 72 vs 73
  await expect(line).toContainText("The macros add up to 72 kcal — that is 1 kcal off.");
  await table(page).getByRole("cell", { name: "Olívaolaj", exact: true }).click(); // 900 vs 884 → 16 off, 1.8 %
  await expect(line).toHaveAttribute("data-tone", "info");
  await table(page).getByRole("cell", { name: "Házi granola", exact: true }).click(); // 180 vs 100 → 80 %
  await expect(line).toHaveAttribute("data-tone", "warning");
  await editor(page).getByRole("textbox", { name: "Calories" }).fill("180");
  await expect(line).toHaveCount(0);
});

test("a new food starts empty, asks for a name and offers the barcode lookup", async ({ page }) => {
  await section(page).getByRole("button", { name: "New food" }).click();
  await expect(editor(page).getByRole("heading", { name: "New food" })).toBeVisible();
  await expect(editor(page).getByRole("button", { name: "Save" })).toBeDisabled();
  await editor(page).getByRole("textbox", { name: "Barcode (optional)" }).fill("5998200");
  await editor(page).getByRole("button", { name: "Look up" }).click();
  await expect(page.getByTestId("foods-log")).toHaveText("Last action: lookup 5998200");
  await editor(page).getByRole("textbox", { name: "Name" }).fill("Kókuszolaj");
  await editor(page).getByRole("textbox", { name: "Fat" }).fill("100");
  await editor(page).getByRole("button", { name: "Save" }).click();
  await expect(page.getByTestId("foods-log")).toHaveText("Last action: save Kókuszolaj|0|0|0|100");
});

test("in Hungarian: Utoljára, 'N étel', 'A makrók … kcal-t adnak ki' and Mentés", async ({ page }) => {
  await page.getByRole("button", { name: "HU", exact: true }).click();
  const hu = section(page);
  await expect(hu.getByRole("table", { name: "Ételek listája" }).getByRole("columnheader", { name: "Utoljára" })).toBeVisible();
  await expect(hu.getByText("18 étel")).toBeVisible();
  await expect(hu.getByPlaceholder("Keresés /")).toBeVisible();
  await hu.getByRole("cell", { name: "Kefir", exact: true }).click();
  await expect(editor(page).getByText("A makrók 72 kcal-t adnak ki — ez 1 kcal-lal tér el.")).toBeVisible();
  await expect(editor(page).getByRole("button", { name: "Mentés" })).toBeDisabled();
});

test("the table does not take focus on load, and arrow keys still move through its rows", async ({ page }) => {
  await expect(table(page).locator("tbody tr").first()).not.toBeFocused();
  await table(page).locator("tbody tr").first().focus();
  await page.keyboard.press("ArrowDown");
  await expect(table(page).locator("tbody tr").nth(1)).toBeFocused();
});
