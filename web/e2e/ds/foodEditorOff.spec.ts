import type { Page } from "@playwright/test";
import { test, expect } from "./fixtures";

/** The food editor's OpenFoodFacts option (docs/84 follow-up) in the gallery's foods section (EN): the same option the add-food
 *  dialog has, on the plain "New food" form — a checkbox, a list to pick from, a filled form. The gallery answers from fixtures. */

const section = (page: Page) => page.locator("#foods-table");
const editor = (page: Page) => page.getByTestId("food-editor");
const box = (page: Page) => editor(page).getByRole("checkbox", { name: "Also search the OpenFoodFacts food database" });
const results = (page: Page) => editor(page).getByTestId("off-section");
const rows = (page: Page) => results(page).getByTestId("off-row");
const name = (page: Page) => editor(page).getByRole("textbox", { name: "Name" });
const requests = (page: Page) => page.getByTestId("foods-off-requests");

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/dev/design");
  await page.evaluate(() => window.localStorage.removeItem("lifey.addFood.offSearch"));
  await page.getByRole("heading", { name: "Foods table and editor", exact: true }).scrollIntoViewIfNeeded();
  await section(page).getByRole("button", { name: "New food" }).click();
  await expect(editor(page)).toBeVisible();
});

test("a new food has the OpenFoodFacts checkbox, unticked; an existing food does not", async ({ page }) => {
  await expect(box(page)).toHaveAttribute("aria-checked", "false");
  await expect(editor(page).getByTestId("off-hint")).toHaveCount(0);

  await section(page).getByRole("cell", { name: "Zabpehely", exact: true }).click();
  await expect(editor(page).getByRole("heading", { name: "Edit food" })).toBeVisible();
  await expect(editor(page).getByTestId("off-option")).toHaveCount(0);
});

test("unticked: typing a name searches nothing and shows no list", async ({ page }) => {
  await name(page).fill("csirkemell");
  await expect(results(page)).toHaveCount(0);
  await expect(requests(page)).toHaveText("OpenFoodFacts requests: 0");
});

test("ticked: the label and hint say it is the OpenFoodFacts database, then a list of products to choose from", async ({ page }) => {
  await box(page).click();
  await expect(editor(page).getByTestId("off-hint")).toContainText("public food database run by volunteers");
  await name(page).fill("csirkemell");

  await expect(results(page).getByText("From the OpenFoodFacts database")).toBeVisible();
  await expect(rows(page)).toHaveCount(3);
  await expect(rows(page).nth(0)).toContainText("Csirkemell");
  await expect(rows(page).nth(0)).toContainText("Pikok");
  await expect(rows(page).nth(0)).toContainText("OFF");
  await expect(rows(page).nth(0)).toContainText("110 kcal / 100 g");
  await expect(requests(page)).toHaveText("OpenFoodFacts requests: 1");
});

test("choosing a product fills name, calories, macros and barcode; the list closes; saving sends exactly those values", async ({ page }) => {
  await box(page).click();
  await name(page).fill("csirkemell");
  await rows(page).nth(0).click();

  await expect(name(page)).toHaveValue("Csirkemell");
  await expect(editor(page).getByRole("textbox", { name: "Calories" })).toHaveValue("110");
  await expect(editor(page).getByRole("textbox", { name: "Protein" })).toHaveValue("14");
  await expect(editor(page).getByRole("textbox", { name: "Carbs" })).toHaveValue("2.4");
  await expect(editor(page).getByRole("textbox", { name: "Fat" })).toHaveValue("4.9");
  await expect(editor(page).getByRole("textbox", { name: "Barcode (optional)" })).toHaveValue("4056489827702");
  await expect(results(page)).toHaveCount(0);
  await expect(editor(page).getByTestId("off-filled")).toContainText("Filled in from the OpenFoodFacts database");
  await expect(requests(page)).toHaveText("OpenFoodFacts requests: 1"); // filling the name did not search again

  await editor(page).getByRole("button", { name: "Save" }).click();
  await expect(page.getByTestId("foods-log")).toHaveText("Last action: save Csirkemell|110|14|2.4|4.9");
});

test("a product without carbs and fat fills them as 0", async ({ page }) => {
  await box(page).click();
  await name(page).fill("rántott");
  await rows(page).nth(0).click();

  await expect(name(page)).toHaveValue("Rántott csirkemell");
  await expect(editor(page).getByRole("textbox", { name: "Carbs" })).toHaveValue("0");
  await expect(editor(page).getByRole("textbox", { name: "Fat" })).toHaveValue("0");
});

test("editing the name after choosing shows the list again", async ({ page }) => {
  await box(page).click();
  await name(page).fill("csirkemell");
  await rows(page).nth(0).click();
  await expect(results(page)).toHaveCount(0);

  await name(page).fill("csirkemell sonka");
  await expect(rows(page)).toHaveCount(1);
  await expect(editor(page).getByTestId("off-filled")).toHaveCount(0);
});

test("under 3 letters it asks for more; unticking removes the list; the choice is remembered when the editor opens again", async ({ page }) => {
  await box(page).click();
  await name(page).fill("cs");
  await expect(results(page)).toContainText("Type at least 3 letters to search OpenFoodFacts.");
  await expect(requests(page)).toHaveText("OpenFoodFacts requests: 0");

  await name(page).fill("csirkemell");
  await expect(rows(page)).toHaveCount(3);
  await box(page).click();
  await expect(results(page)).toHaveCount(0);
  await box(page).click(); // ticked again
  await editor(page).getByRole("button", { name: "Cancel" }).click();

  await section(page).getByRole("button", { name: "New food" }).click();
  await expect(box(page)).toHaveAttribute("aria-checked", "true");
});

test("the English fallback, an unavailable service and rate limiting each get their line; nothing found says so", async ({ page }) => {
  await box(page).click();
  await name(page).fill("pumpkin");
  await expect(results(page).getByRole("note")).toContainText("Nothing found among products sold in Hungary");
  await name(page).fill("unavail");
  await expect(results(page).getByRole("note")).toHaveText("OpenFoodFacts isn't answering right now.");
  await name(page).fill("limited");
  await expect(results(page).getByRole("note")).toHaveText("Too many searches — try again in a minute.");
  await name(page).fill("zzzxyz");
  await expect(results(page)).toContainText("Nothing found on OpenFoodFacts.");
});

test("on a phone nothing scrolls sideways", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await box(page).scrollIntoViewIfNeeded();
  await box(page).click();
  await name(page).fill("csirkemell");
  await expect(rows(page).first()).toBeVisible();
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  expect(overflow).toBeLessThanOrEqual(0);
});
