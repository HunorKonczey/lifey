import { test, expect, type APIRequestContext } from "@playwright/test";

/**
 * Fibre and sugars per 100 g on a food, and their totals on a meal and on the day (LIF-145): the server returns them on the
 * food and, scaled to the grams, on a meal entry; the meals tab shows a meal's and the day's totals - and says so when only
 * some foods have a figure; the food editor saves a typed figure, keeps an unknown one unknown (it is not 0) and refuses a
 * typo.
 *
 * Requires the real backend + Postgres on localhost:8080/5432, same as the other specs in this folder.
 */

const API_BASE = "http://localhost:8080/api/v1";
const PASSWORD = "E2eFiberSugar123!";

async function registerAndLogin(request: APIRequestContext, email: string) {
  const registerRes = await request.post(`${API_BASE}/auth/register`, { data: { email, password: PASSWORD, firstName: "E2E", lastName: "Fibre" } });
  expect(registerRes.ok(), await registerRes.text()).toBeTruthy();
  const loginRes = await request.post(`${API_BASE}/auth/login`, { data: { email, password: PASSWORD } });
  expect(loginRes.ok(), await loginRes.text()).toBeTruthy();
  return (await loginRes.json()).accessToken as string;
}

test("fibre and sugar: stored per food, totalled per meal and day, edited in the food editor", async ({ page, request }) => {
  const runId = Date.now();
  const email = `e2e-fiber-sugar-${runId}@example.com`;
  const token = await registerAndLogin(request, email);
  const auth = { Authorization: `Bearer ${token}` };
  const oats = `Oats ${runId}`;
  const mystery = `Mystery bar ${runId}`;
  let oatsId = 0;
  let mysteryId = 0;

  await test.step("the API stores the figures, rejects a negative one, and scales them into a meal entry", async () => {
    const created = await request.post(`${API_BASE}/foods`, {
      headers: auth,
      data: { name: oats, caloriesPer100g: 370, proteinPer100g: 13, carbsPer100g: 60, fatPer100g: 7, fiberPer100g: 10, sugarPer100g: 1.2, hidden: false },
    });
    expect(created.ok(), await created.text()).toBeTruthy();
    const food = await created.json();
    oatsId = food.id;
    expect(food.fiberPer100g).toBe(10);
    expect(food.sugarPer100g).toBe(1.2);

    const bar = await request.post(`${API_BASE}/foods`, { headers: auth, data: { name: mystery, caloriesPer100g: 400, proteinPer100g: 8, carbsPer100g: 50, fatPer100g: 15, hidden: false } });
    expect(bar.ok(), await bar.text()).toBeTruthy();
    mysteryId = (await bar.json()).id;
    expect((await bar.json()).fiberPer100g ?? null).toBeNull();

    const negative = await request.post(`${API_BASE}/foods`, { headers: auth, data: { name: `Bad ${runId}`, caloriesPer100g: 1, proteinPer100g: 1, fiberPer100g: -1, hidden: false } });
    expect(negative.status()).toBe(400);

    const meal = await request.post(`${API_BASE}/meals`, {
      headers: auth,
      data: { dateTime: new Date(Date.now() - 60_000).toISOString(), mealType: "BREAKFAST", entries: [{ foodId: oatsId, quantityInGrams: 150 }, { foodId: mysteryId, quantityInGrams: 50 }] },
    });
    expect(meal.ok(), await meal.text()).toBeTruthy();
    const entries: Array<{ foodName: string; fiber: number | null; sugar: number | null }> = (await meal.json()).entries;
    const oatEntry = entries.find((e) => e.foodName === oats)!;
    expect(oatEntry.fiber).toBeCloseTo(15, 6);
    expect(oatEntry.sugar).toBeCloseTo(1.8, 6);
    expect(entries.find((e) => e.foodName === mystery)!.fiber).toBeNull();
  });

  await page.goto("/login");
  await page.getByPlaceholder("you@example.com").fill(email);
  await page.getByPlaceholder("••••••••").fill(PASSWORD);
  await page.getByRole("button", { name: "Sign in" }).click();
  await page.waitForURL(/dashboard|onboarding/);

  await test.step("the meals tab shows the meal's and the day's totals, and that one food has no figure", async () => {
    await page.goto("/nutrition");
    const mealLine = page.getByTestId("meal-fiber-sugar");
    await expect(mealLine).toBeVisible();
    await expect(mealLine).toContainText("Fibre 15 g");
    await expect(mealLine).toContainText("Sugar 1.8 g");
    await expect(mealLine).toContainText("some foods have no figure");
    await expect(page.getByTestId("summary-fiber-sugar")).toContainText("Fibre 15 g");
  });

  await test.step("the food editor keeps a stored figure, saves a typed one, and refuses a typo", async () => {
    await page.goto("/nutrition?tab=foods");
    const row = page.getByRole("row").filter({ hasText: mystery });
    await row.getByRole("button", { name: /Actions for/ }).click();
    await page.getByRole("menuitem", { name: "Edit" }).click();

    const editor = page.getByTestId("food-editor");
    const fiber = editor.getByLabel("Fibre");
    const sugar = editor.getByLabel("Sugar");
    await expect(fiber).toHaveValue("");

    await fiber.fill("abc");
    await editor.getByRole("button", { name: "Save" }).click();
    await expect(editor.getByText("A number from 0 to 100")).toBeVisible();

    await fiber.fill("8,5");
    await sugar.fill("0");
    await editor.getByRole("button", { name: "Save" }).click();

    await expect.poll(async () => {
      const list: Array<{ id: number; fiberPer100g: number | null; sugarPer100g: number | null }> = await (await request.get(`${API_BASE}/foods`, { headers: auth })).json();
      const f = list.find((x) => x.id === mysteryId)!;
      return [f.fiberPer100g, f.sugarPer100g];
    }).toEqual([8.5, 0]);
  });

  await test.step("an unrelated edit of a food that has figures does not erase them", async () => {
    const list: Array<{ id: number; name: string; fiberPer100g: number | null; sugarPer100g: number | null }> = await (await request.get(`${API_BASE}/foods`, { headers: auth })).json();
    const stored = list.find((x) => x.id === oatsId)!;
    expect(stored.fiberPer100g).toBe(10);

    await page.goto("/nutrition?tab=foods");
    const row = page.getByRole("row").filter({ hasText: oats });
    await row.getByRole("button", { name: /Actions for/ }).click();
    await page.getByRole("menuitem", { name: "Edit" }).click();
    const editor = page.getByTestId("food-editor");
    await expect(editor.getByLabel("Fibre")).toHaveValue("10");
    await editor.getByLabel("Name").fill(`${oats} v2`);
    await editor.getByRole("button", { name: "Save" }).click();

    await expect.poll(async () => {
      const after: Array<{ id: number; name: string; fiberPer100g: number | null; sugarPer100g: number | null }> = await (await request.get(`${API_BASE}/foods`, { headers: auth })).json();
      const f = after.find((x) => x.id === oatsId)!;
      return [f.name, f.fiberPer100g, f.sugarPer100g];
    }).toEqual([`${oats} v2`, 10, 1.2]);
  });
});
