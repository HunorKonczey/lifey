import type { Page } from "@playwright/test";
import { test, expect } from "./fixtures";

/** Nutrition at 390 (W2.12, W2-F) against the gallery's "Nutrition on a phone": the three-part tab switch, the
 *  FAB, the compact day summary, the "150 g · P 20" rows, the undo toast clearing the FAB, and — at 1440 —
 *  the desktop shapes untouched. */

const section = (page: Page) => page.getByTestId("nutrition-mobile");
const log = (page: Page) => page.getByTestId("mobile-log");

test.describe("at 390", () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto("/dev/design");
    await page.getByRole("heading", { name: "Nutrition on a phone", exact: true }).scrollIntoViewIfNeeded();
  });

  test("the tabs are one full-width segmented control of three 44 px parts, with their counts", async ({ page }) => {
    const group = section(page).getByRole("radiogroup", { name: "Nutrition sections" });
    const radios = group.getByRole("radio");
    await expect(radios).toHaveText(["Meals", "Foods 18", "Recipes 4"]);
    const boxes = await radios.evaluateAll((els) => els.map((e) => e.getBoundingClientRect()));
    for (const b of boxes) expect(b.height).toBeGreaterThanOrEqual(44);
    expect(Math.abs(boxes[0].width - boxes[1].width)).toBeLessThan(40); // equal shares, give or take the label
    await radios.nth(1).click();
    await expect(log(page)).toContainText("tab: foods");
  });

  test("copy is an icon beside the tabs on the meals tab only", async ({ page }) => {
    await expect(section(page).getByRole("button", { name: "Copy from an earlier day" })).toBeVisible();
    await section(page).getByRole("radio", { name: /Recipes/ }).click();
    await expect(section(page).getByRole("button", { name: "Copy from an earlier day" })).toHaveCount(0);
  });

  test("a FAB carries the primary action: Food on meals and foods, Recipe on recipes", async ({ page }) => {
    const fab = page.getByTestId("fab");
    await expect(fab).toContainText("Food");
    await expect(fab).toHaveAccessibleName("Add food");
    await fab.click();
    await expect(log(page)).toContainText("add food");
    await section(page).getByRole("radio", { name: /Recipes/ }).click();
    await expect(fab).toContainText("Recipe");
    await fab.click();
    await expect(log(page)).toContainText("new recipe");
  });

  test("the FAB floats above the bottom nav's top edge at the right", async ({ page }) => {
    const box = (await page.getByTestId("fab").boundingBox())!;
    expect(box.height).toBe(56);
    expect(Math.round(844 - (box.y + box.height))).toBe(96); // 96 px above the bottom: the nav's top edge (80) plus a gap
    expect(Math.round(390 - (box.x + box.width))).toBe(16);
    expect(await page.evaluate(() => document.documentElement.style.getPropertyValue("--fab-clearance"))).toBe("72px");
  });

  test("the undo toast sits above the FAB and the nav, inside the screen", async ({ page }) => {
    await section(page).getByRole("button", { name: "Show delete toast" }).click();
    const toast = page.getByRole("status").filter({ hasText: "Snack törölve" });
    await expect(toast).toBeVisible();
    await expect(toast.getByRole("button", { name: "Undo" })).toBeVisible();
    await page.waitForTimeout(500); // the enter animation settles
    const t = (await toast.boundingBox())!;
    const f = (await page.getByTestId("fab").boundingBox())!;
    expect(t.y + t.height).toBeLessThanOrEqual(f.y); // clear of the FAB
    expect(Math.round(844 - (t.y + t.height))).toBe(164); // 92 above the bottom without a FAB, plus its 72
    expect(t.x).toBeGreaterThanOrEqual(0);
    expect(t.x + t.width).toBeLessThanOrEqual(390);
  });

  test("the day summary is the compact card: ring, three mini macro rows, no title and no eaten / goal block", async ({ page }) => {
    const summary = section(page).getByTestId("day-summary");
    await expect(summary.getByTestId("summary-number")).toHaveText("859");
    await expect(summary.getByTestId("summary-protein")).toContainText("68 / 120 g");
    await expect(summary.getByTestId("summary-fat")).toBeVisible();
    await expect(summary.getByText("Daily summary")).toBeHidden();
    await expect(summary.getByText("Eaten")).toBeHidden();
    const ring = (await summary.getByRole("img").first().boundingBox())!;
    expect(ring.width).toBeLessThanOrEqual(96);
    const card = (await summary.boundingBox())!;
    expect(card.height).toBeLessThan(200);
  });

  test("meal rows read '150 g · P 15' with the kcal on the right; carbs and fat move to the editor", async ({ page }) => {
    const rows = section(page).getByTestId("meal-card").locator(".meal-item-row");
    await expect(rows.nth(1).getByText("150 g · P 15")).toBeVisible();
    await expect(rows.nth(1).getByText("110")).toBeVisible();
    await expect(rows.nth(1).locator("dl")).toBeHidden();
  });

  test("no horizontal scrolling", async ({ page }) => {
    const { doc, client } = await page.evaluate(() => ({ doc: document.documentElement.scrollWidth, client: document.documentElement.clientWidth }));
    expect(doc).toBe(client);
  });

  test("the copy-from-day panel is a bottom sheet that fits the screen", async ({ page }) => {
    await page.getByRole("heading", { name: "Copy from day popover", exact: true }).scrollIntoViewIfNeeded();
    await page.getByTestId("open-copy-from-day").click();
    const panel = page.getByTestId("copy-from-day");
    await expect(panel).toBeVisible();
    const box = (await panel.boundingBox())!;
    expect(box.x).toBeGreaterThanOrEqual(0);
    expect(box.x + box.width).toBeLessThanOrEqual(390);
    expect(Math.round(844 - (box.y + box.height))).toBeLessThan(40); // anchored to the bottom like a sheet
  });

  test("the foods table is a list of cards without the density switch", async ({ page }) => {
    await page.getByRole("heading", { name: "Foods table and editor", exact: true }).scrollIntoViewIfNeeded();
    const foods = page.locator("#foods-table");
    await expect(foods.getByRole("list", { name: "Food list" })).toBeVisible();
    await expect(foods.getByRole("radiogroup", { name: "Row density" })).toBeHidden();
  });
});

test.describe("at 1440", () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto("/dev/design");
    await page.getByRole("heading", { name: "Nutrition on a phone", exact: true }).scrollIntoViewIfNeeded();
  });

  test("underline tabs and the button row stay, there is no FAB and no clearance", async ({ page }) => {
    await expect(section(page).getByRole("tab", { name: /Foods/ })).toBeVisible();
    await expect(section(page).getByRole("button", { name: /Add food/ })).toBeVisible();
    await expect(page.getByTestId("fab")).toHaveCount(0);
    expect(await page.evaluate(() => document.documentElement.style.getPropertyValue("--fab-clearance"))).toBe("");
  });

  test("the day summary keeps its title and eaten / goal block", async ({ page }) => {
    const summary = section(page).getByTestId("day-summary");
    await expect(summary.getByText("Daily summary")).toBeVisible();
    await expect(summary.getByText("Eaten")).toBeVisible();
  });

  test("the toast stays 24 px from the bottom", async ({ page }) => {
    await section(page).getByRole("button", { name: "Show delete toast" }).click();
    await page.waitForTimeout(500); // the enter animation settles
    const t = (await page.getByRole("status").filter({ hasText: "Snack törölve" }).boundingBox())!;
    expect(Math.round(900 - (t.y + t.height))).toBe(24);
  });
});

test("in Hungarian: Étkezések · Ételek 18 · Receptek 4, the FAB 'Étel' and 'F 15'", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Nutrition on a phone", exact: true }).scrollIntoViewIfNeeded();
  await page.getByRole("button", { name: "HU", exact: true }).click();
  await expect(section(page).getByRole("radio")).toHaveText(["Étkezések", "Ételek 18", "Receptek 4"]);
  await expect(page.getByTestId("fab")).toContainText("Étel");
  await expect(section(page).getByText("150 g · F 15")).toBeVisible();
});
