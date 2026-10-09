import { test, expect, type APIRequestContext } from "@playwright/test";

/**
 * Named serving sizes on a food (LIF-146): stored in order by the server, edited in the food editor (add, remove, a typo is
 * refused), and offered as chips in the add-food dialog - tapping "1 glass · 200 g" sets the quantity. An update from a client that
 * knows nothing about servings keeps them; an empty list clears them.
 *
 * Requires the real backend + Postgres on localhost:8080/5432, same as the other specs in this folder.
 */

const API_BASE = "http://localhost:8080/api/v1";
const PASSWORD = "E2eServings123!";

async function registerAndLogin(request: APIRequestContext, email: string) {
  const registerRes = await request.post(`${API_BASE}/auth/register`, { data: { email, password: PASSWORD, firstName: "E2E", lastName: "Serving" } });
  expect(registerRes.ok(), await registerRes.text()).toBeTruthy();
  const loginRes = await request.post(`${API_BASE}/auth/login`, { data: { email, password: PASSWORD } });
  expect(loginRes.ok(), await loginRes.text()).toBeTruthy();
  return (await loginRes.json()).accessToken as string;
}

test("servings: stored in order, edited in the food editor, offered as quantity chips", async ({ page, request }) => {
  const runId = Date.now();
  const email = `e2e-servings-${runId}@example.com`;
  const token = await registerAndLogin(request, email);
  const auth = { Authorization: `Bearer ${token}` };
  const milk = `Milk ${runId}`;
  let milkId = 0;

  const stored = async () => {
    const list: Array<{ id: number; name: string; caloriesPer100g: number; proteinPer100g: number; servings: Array<{ name: string; grams: number }> }> = await (
      await request.get(`${API_BASE}/foods`, { headers: auth })
    ).json();
    return list.find((f) => f.id === milkId)!;
  };

  await test.step("the API keeps the servings in order, refuses a bad one, and an update without the field keeps them", async () => {
    const created = await request.post(`${API_BASE}/foods`, {
      headers: auth,
      data: { name: milk, caloriesPer100g: 46, proteinPer100g: 3.4, hidden: false, servings: [{ name: "1 glass", grams: 200 }, { name: "1 spoon", grams: 15 }] },
    });
    expect(created.ok(), await created.text()).toBeTruthy();
    milkId = (await created.json()).id;
    expect((await stored()).servings).toEqual([{ name: "1 glass", grams: 200 }, { name: "1 spoon", grams: 15 }]);

    const bad = await request.post(`${API_BASE}/foods`, { headers: auth, data: { name: `Bad ${runId}`, caloriesPer100g: 1, proteinPer100g: 1, hidden: false, servings: [{ name: "x", grams: 0 }] } });
    expect(bad.status()).toBe(400);

    const ordinary = await request.put(`${API_BASE}/foods/${milkId}`, { headers: auth, data: { name: milk, caloriesPer100g: 47, proteinPer100g: 3.4, hidden: false } });
    expect(ordinary.ok(), await ordinary.text()).toBeTruthy();
    expect((await stored()).servings).toHaveLength(2);
  });

  await page.goto("/login");
  await page.getByPlaceholder("you@example.com").fill(email);
  await page.getByPlaceholder("••••••••").fill(PASSWORD);
  await page.getByRole("button", { name: "Sign in" }).click();
  await page.waitForURL(/dashboard|onboarding/);

  await test.step("the add-food dialog offers the servings as chips, and a tap sets the quantity", async () => {
    await page.goto("/nutrition");
    await page.getByRole("button", { name: /Add food/ }).first().click();
    await page.getByPlaceholder("Search foods and recipes").fill(milk);
    await page.getByRole("option").filter({ hasText: milk }).first().click();

    const chips = page.getByRole("group", { name: "Quick quantities" });
    await expect(chips.getByRole("button")).toHaveText(["1 glass · 200 g", "1 spoon · 15 g", "100 g"]);

    await chips.getByRole("button", { name: "1 glass · 200 g" }).click();
    await expect(chips.getByRole("button", { name: "1 glass · 200 g" })).toHaveAttribute("aria-pressed", "true");
    await expect(page.getByLabel(/Quantity|Amount/i).first()).toHaveValue(/^200/);
    await page.keyboard.press("Escape");
  });

  await test.step("the editor shows the servings, adds one, refuses a half-filled one, and saves the list in order", async () => {
    await page.goto("/nutrition?tab=foods");
    const row = page.getByRole("row").filter({ hasText: milk });
    await row.getByRole("button", { name: /Actions for/ }).click();
    await page.getByRole("menuitem", { name: "Edit" }).click();

    const editor = page.getByTestId("food-editor");
    const rows = editor.getByTestId("serving-row");
    await expect(rows).toHaveCount(2);
    await expect(rows.nth(0).getByTestId("serving-name")).toHaveValue("1 glass");
    await expect(rows.nth(0).getByTestId("serving-grams")).toHaveValue("200");

    await editor.getByTestId("add-serving").click();
    await expect(rows).toHaveCount(3);
    await rows.nth(2).getByTestId("serving-name").fill("1 cup");
    await editor.getByRole("button", { name: "Save" }).click();
    await expect(editor.getByText("A name and an amount from 0 to 5000 g")).toBeVisible();

    await rows.nth(2).getByTestId("serving-grams").fill("250,5");
    await editor.getByRole("button", { name: "Save" }).click();

    await expect.poll(async () => (await stored()).servings).toEqual([
      { name: "1 glass", grams: 200 },
      { name: "1 spoon", grams: 15 },
      { name: "1 cup", grams: 250.5 },
    ]);
  });

  await test.step("removing every serving clears them", async () => {
    await page.goto("/nutrition?tab=foods");
    const row = page.getByRole("row").filter({ hasText: milk });
    await row.getByRole("button", { name: /Actions for/ }).click();
    await page.getByRole("menuitem", { name: "Edit" }).click();

    const editor = page.getByTestId("food-editor");
    for (let i = 0; i < 3; i++) await editor.getByRole("button", { name: "Remove serving" }).first().click();
    await expect(editor.getByTestId("serving-row")).toHaveCount(0);
    await editor.getByRole("button", { name: "Save" }).click();

    await expect.poll(async () => (await stored()).servings).toEqual([]);
  });
});
