import { test, expect } from "@playwright/test";

/** DataTable v2 (D-W0.15) against the gallery's "Data table" DS-03 foods
 *  sample: search, sort, density, keyboard nav, row menu, pagination, and
 *  the card-row layout under 768px. */

test.beforeEach(async ({ page }) => {
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Data table", exact: true }).scrollIntoViewIfNeeded();
});

test("search filters rows by name", async ({ page }) => {
  // exact: true — a row's "…" cell's accessible name ("More actions for
  // Chicken breast") otherwise also matches "Chicken breast" as a substring.
  await expect(page.getByRole("cell", { name: "Chicken breast", exact: true })).toBeVisible();
  await page.getByPlaceholder("Search foods… (press /)").fill("avocado");
  await expect(page.getByRole("cell", { name: "Chicken breast", exact: true })).toHaveCount(0);
  await expect(page.getByRole("cell", { name: "Avocado", exact: true })).toBeVisible();
});

test("clicking a sortable header sorts, and clicking again reverses it", async ({ page }) => {
  const table = page.getByRole("table", { name: "Foods" });
  const firstCell = table.locator("tbody tr").first().locator("td").first();
  await table.getByRole("columnheader", { name: "Kcal / 100g" }).click();
  await expect(firstCell).toHaveText("Spinach"); // lowest kcal, ascending
  await table.getByRole("columnheader", { name: "Kcal / 100g" }).click();
  await expect(firstCell).toHaveText("Olive oil"); // highest kcal, descending
});

test("arrow keys move the active row and Enter opens (selects) it", async ({ page }) => {
  const table = page.getByRole("table", { name: "Foods" });
  const rows = table.locator("tbody tr");
  await rows.first().focus();
  await page.keyboard.press("ArrowDown");
  await page.keyboard.press("ArrowDown");
  await page.keyboard.press("Enter");
  await expect(rows.nth(2)).toHaveAttribute("data-selected", "true");
  await expect(rows.first()).not.toHaveAttribute("data-selected", "true");
});

test("Shift+F10 opens the active row's menu", async ({ page }) => {
  const table = page.getByRole("table", { name: "Foods" });
  await table.locator("tbody tr").first().focus();
  await page.keyboard.press("Shift+F10");
  await expect(page.getByRole("menuitem", { name: "Edit" })).toBeVisible();
});

test("the density switch changes row height", async ({ page }) => {
  const row = page.getByRole("table", { name: "Foods" }).locator("tbody tr").first();
  const comfortableHeight = (await row.boundingBox())!.height;
  await page.getByRole("radio", { name: "Compact" }).click();
  const compactHeight = (await row.boundingBox())!.height;
  expect(compactHeight).toBeLessThan(comfortableHeight);
});

test("pagination shows 10 rows on the first page and the rest on the second", async ({ page }) => {
  const rows = page.getByRole("table", { name: "Foods" }).locator("tbody tr");
  await expect(rows).toHaveCount(10);
  await expect(page.getByText("18 foods", { exact: false })).toBeVisible();
  await page.getByRole("button", { name: "Next page" }).click();
  await expect(rows).toHaveCount(8);
});

test("under 768px every row renders as a card instead of a table", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await expect(page.getByRole("table", { name: "Foods" })).toHaveCount(0);
  const list = page.getByRole("list", { name: "Foods" });
  await expect(list).toBeVisible();
  await expect(list.getByText("Chicken breast")).toBeVisible();
  await expect(list.getByText("165 kcal/100g")).toBeVisible();
});
