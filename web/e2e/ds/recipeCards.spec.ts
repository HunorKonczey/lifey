import type { Page } from "@playwright/test";
import { test, expect } from "./fixtures";

/** Recipe cards and the log-recipe modal (W2.11) against the gallery's section (EN, 1440): kcal per serving
 *  large, the dominant-macro icon, the macro line in metric colours, the actions, the container-driven
 *  column count, and the modal's portions / per-ingredient grams / preview. */

const section = (page: Page) => page.locator("#recipe-cards");
const cards = (page: Page) => section(page).getByTestId("recipe-card");
const card = (page: Page, n: number) => cards(page).nth(n);
const log = (page: Page) => section(page).getByTestId("recipe-log");
const modal = (page: Page) => page.locator("#lifey-overlay-root").getByRole("dialog", { name: /Log as meal|Rögzítés étkezésként/ });

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Recipe cards and log modal", exact: true }).scrollIntoViewIfNeeded();
});

test("a card shows the name, servings · ingredients, kcal per serving and the macros per serving", async ({ page }) => {
  const rice = card(page, 0);
  await expect(rice.getByText("Csirkés rizstál brokkolival")).toBeVisible();
  await expect(rice.getByText("4 servings · 5 ingredients")).toBeVisible();
  await expect(rice.getByText("528", { exact: true })).toBeVisible();
  await expect(rice.getByText("kcal / serving")).toBeVisible();
  await expect(rice.getByTestId("recipe-macros")).toHaveText("P 38 g · C 58 g · F 14 g");
});

test("the icon takes the dominant macro's colour: carbs, protein, fat, and a neutral book without data", async ({ page }) => {
  const macro = (n: number) => card(page, n).getByTestId("recipe-tint-icon");
  await expect(macro(0)).toHaveAttribute("data-macro", "carbs");
  await expect(macro(1)).toHaveAttribute("data-macro", "protein");
  await expect(macro(2)).toHaveAttribute("data-macro", "fat");
  await expect(macro(3)).toHaveAttribute("data-macro", "none");
});

test("only a favourite recipe carries the star", async ({ page }) => {
  await expect(card(page, 0).getByRole("img", { name: "Favorite" })).toBeVisible();
  await expect(section(page).getByRole("img", { name: "Favorite" })).toHaveCount(1);
});

test("only a recipe a trainer assigned carries the 'From your trainer' chip (LIF-104)", async ({ page }) => {
  await expect(card(page, 1).getByTestId("recipe-from-trainer")).toContainText("From your trainer");
  await expect(section(page).getByTestId("recipe-from-trainer")).toHaveCount(1);
  await expect(card(page, 0).getByText("From your trainer")).toHaveCount(0);
});

test("a long name wraps onto two lines instead of pushing the card wider", async ({ page }) => {
  const long = card(page, 2);
  const box = await long.boundingBox();
  const other = await card(page, 1).boundingBox();
  expect(Math.abs(box!.width - other!.width)).toBeLessThan(2);
  await expect(long.getByText(/Avokádós pirítós/)).toBeVisible();
});

test("the card's top opens it, 'Log' logs and the '⋯' has Edit, Duplicate and a destructive Delete…", async ({ page }) => {
  await card(page, 1).getByText("Görög joghurtos zabkása").click();
  await expect(log(page)).toHaveText("Last action: open 2");
  await card(page, 1).getByRole("button", { name: "Log" }).click();
  await expect(log(page)).toHaveText("Last action: log 2");
  await card(page, 1).getByRole("button", { name: "Actions for Görög joghurtos zabkása" }).click();
  await expect(page.getByRole("menuitem")).toHaveText([/Edit/, /Duplicate/, /Delete…/]);
  await page.getByRole("menuitem", { name: /Duplicate/ }).click();
  await expect(log(page)).toHaveText("Last action: duplicate 2");
});

test("three columns on a wide pane, one on a phone", async ({ page }) => {
  const columns = async () => new Set(await cards(page).evaluateAll((els) => els.map((e) => Math.round(e.getBoundingClientRect().left)))).size;
  expect(await columns()).toBe(3);
  await page.setViewportSize({ width: 390, height: 844 });
  await expect.poll(columns).toBe(1);
});

test("in Hungarian: adag, hozzávaló, kcal / adag, F · Sz · Zs and Naplózás", async ({ page }) => {
  await page.getByRole("button", { name: "HU", exact: true }).click();
  const rice = card(page, 0);
  await expect(rice.getByText("4 adag · 5 hozzávaló")).toBeVisible();
  await expect(rice.getByText("kcal / adag")).toBeVisible();
  await expect(rice.getByTestId("recipe-macros")).toHaveText("F 38 g · Sz 58 g · Zs 14 g");
  await expect(rice.getByRole("button", { name: "Naplózás" })).toBeVisible();
});

test.describe("log-recipe modal", () => {
  test.beforeEach(async ({ page }) => {
    await card(page, 0).getByRole("button", { name: "Log" }).click();
    await expect(modal(page)).toBeVisible();
  });

  test("opens on lunch with the recipe split into its 4 servings and the preview of one portion", async ({ page }) => {
    await expect(modal(page).getByRole("radio", { name: "Lunch" })).toBeChecked();
    await expect(modal(page).getByRole("switch", { name: "Log a single portion" })).toBeChecked();
    await expect(modal(page).getByRole("textbox", { name: "Split into" })).toHaveValue("4");
    await expect(modal(page).getByTestId("log-preview")).toHaveText("426 kcal · P 52 g · C 37 g · F 7 g");
  });

  test("switching the portion off logs the whole recipe; changing the split rescales", async ({ page }) => {
    await modal(page).getByRole("textbox", { name: "Split into" }).fill("2");
    await modal(page).getByRole("textbox", { name: "Split into" }).blur();
    await expect(modal(page).getByTestId("log-preview")).toContainText("851 kcal");
    await modal(page).getByRole("switch", { name: "Log a single portion" }).click();
    await expect(modal(page).getByTestId("log-preview")).toHaveText("1,702 kcal · P 209 g · C 147 g · F 28 g");
  });

  test("Log sends the meal type and each ingredient's grams for one portion", async ({ page }) => {
    await modal(page).getByRole("radio", { name: "Dinner" }).click();
    await modal(page).getByRole("button", { name: "Log meal" }).click();
    await expect(log(page)).toHaveText("Last action: logged DINNER: 1:150,2:120,3:90");
    await expect(modal(page)).toHaveCount(0);
  });

  test("'Adjust ingredients' overrides grams; 0 leaves an ingredient out and the preview follows", async ({ page }) => {
    await modal(page).getByRole("button", { name: "Adjust ingredients" }).click();
    const chicken = modal(page).getByRole("textbox", { name: "Csirkemell" });
    await expect(chicken).toHaveValue("150");
    await chicken.fill("0");
    await chicken.blur();
    // only rice and broccoli are left: (590 + 122) / 4 kcal, (13 + 10) / 4 g protein
    await expect(modal(page).getByTestId("log-preview")).toHaveText("178 kcal · P 6 g · C 37 g · F 2 g");
    await modal(page).getByRole("button", { name: "Log meal" }).click();
    await expect(log(page)).toHaveText("Last action: logged LUNCH: 2:120,3:90");
  });

  test("a reset button puts an overridden amount back", async ({ page }) => {
    await modal(page).getByRole("button", { name: "Adjust ingredients" }).click();
    const rice = modal(page).getByRole("textbox", { name: "Barna rizs" });
    await rice.fill("200");
    await rice.blur();
    await modal(page).getByRole("button", { name: "Reset to recipe amount" }).click();
    await expect(rice).toHaveValue("120");
  });

  test("Esc closes it without logging", async ({ page }) => {
    await page.keyboard.press("Escape");
    await expect(modal(page)).toHaveCount(0);
    await expect(log(page)).toHaveText("Last action: log 1");
  });

  test("in Hungarian: Étkezés, Egy adag rögzítése, preview with F / Sz / Zs", async ({ page }) => {
    await page.keyboard.press("Escape");
    await page.getByRole("button", { name: "HU", exact: true }).click();
    await card(page, 0).getByRole("button", { name: "Naplózás" }).click();
    const hu = page.locator("#lifey-overlay-root").getByRole("dialog", { name: "Rögzítés étkezésként" });
    await expect(hu.getByRole("switch", { name: "Egy adag rögzítése" })).toBeChecked();
    await expect(hu.getByTestId("log-preview")).toHaveText("426 kcal · F 52 g · Sz 37 g · Zs 7 g");
    await expect(hu.getByRole("button", { name: "Étkezés rögzítése" })).toBeVisible();
  });
});
