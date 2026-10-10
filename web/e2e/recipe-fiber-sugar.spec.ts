import { test, expect, type APIRequestContext } from "@playwright/test";

/**
 * Fibre and sugars of a recipe (LIF-150): worked out from the foods its ingredients point at, shown per serving on the recipe
 * card, as a total and per serving in the editor and for the logged portion in the log dialog - with a note when an ingredient's
 * food has no figure, and nothing at all when none has.
 *
 * Requires the real backend + Postgres on localhost:8080/5432, same as the other specs in this folder.
 */

const API_BASE = "http://localhost:8080/api/v1";
const PASSWORD = "E2eRecipeFibre123!";

async function registerAndLogin(request: APIRequestContext, email: string) {
  const registerRes = await request.post(`${API_BASE}/auth/register`, { data: { email, password: PASSWORD, firstName: "E2E", lastName: "Recipe" } });
  expect(registerRes.ok(), await registerRes.text()).toBeTruthy();
  const loginRes = await request.post(`${API_BASE}/auth/login`, { data: { email, password: PASSWORD } });
  expect(loginRes.ok(), await loginRes.text()).toBeTruthy();
  return (await loginRes.json()).accessToken as string;
}

test("recipe fibre and sugar: per serving on the card, total and per serving in the editor, the portion in the log dialog", async ({ page, request }) => {
  const runId = Date.now();
  const email = `e2e-recipe-fibre-${runId}@example.com`;
  const token = await registerAndLogin(request, email);
  const auth = { Authorization: `Bearer ${token}` };

  const makeFood = async (name: string, extra: Record<string, number>) => {
    const res = await request.post(`${API_BASE}/foods`, {
      headers: auth,
      data: { name: `${name} ${runId}`, caloriesPer100g: 100, proteinPer100g: 5, carbsPer100g: 10, fatPer100g: 2, hidden: false, ...extra },
    });
    expect(res.ok(), await res.text()).toBeTruthy();
    return (await res.json()).id as number;
  };
  const makeRecipe = async (name: string, servings: number, ingredients: Array<{ foodId: number; quantityInGrams: number }>) => {
    const res = await request.post(`${API_BASE}/recipes`, { headers: auth, data: { name, description: null, favorite: false, servings, ingredients } });
    expect(res.ok(), await res.text()).toBeTruthy();
  };

  const oats = await makeFood("Oats", { fiberPer100g: 10, sugarPer100g: 1 });
  const apple = await makeFood("Apple", { fiberPer100g: 2.4, sugarPer100g: 10 });
  const mystery = await makeFood("Mystery", {});

  const full = `Full bowl ${runId}`;
  const partial = `Partial bowl ${runId}`;
  const plain = `Plain bowl ${runId}`;
  // 100 g oats + 200 g apple over 2 servings: fibre (10 + 4.8) / 2 = 7.4 g, sugar (1 + 20) / 2 = 10.5 g per serving.
  await makeRecipe(full, 2, [{ foodId: oats, quantityInGrams: 100 }, { foodId: apple, quantityInGrams: 200 }]);
  await makeRecipe(partial, 1, [{ foodId: oats, quantityInGrams: 100 }, { foodId: mystery, quantityInGrams: 100 }]);
  await makeRecipe(plain, 1, [{ foodId: mystery, quantityInGrams: 100 }]);

  await page.goto("/login");
  await page.getByPlaceholder("you@example.com").fill(email);
  await page.getByPlaceholder("••••••••").fill(PASSWORD);
  await page.getByRole("button", { name: "Sign in" }).click();
  await page.waitForURL(/dashboard|onboarding/);

  const card = (name: string) => page.getByTestId("recipe-card").filter({ hasText: name });

  await test.step("the card shows one serving's fibre and sugar, a note when partial, and nothing when unknown", async () => {
    await page.goto("/nutrition?tab=recipes");
    await expect(card(full).getByTestId("recipe-fiber-sugar")).toHaveText("Fibre 7.4 g · Sugar 10.5 g");
    await expect(card(partial).getByTestId("recipe-fiber-sugar")).toHaveText("Fibre 10 g · Sugar 1 g · some foods have no figure");
    await expect(card(plain)).toBeVisible();
    await expect(card(plain).getByTestId("recipe-fiber-sugar")).toHaveCount(0);
  });

  await test.step("the editor shows the total and the serving", async () => {
    await card(full).getByRole("button").first().click();
    await expect(page.getByTestId("recipe-total-fiber-sugar")).toHaveText("Total: Fibre 14.8 g · Sugar 21 g");
    await expect(page.getByTestId("recipe-serving-fiber-sugar")).toHaveText("Per serving: Fibre 7.4 g · Sugar 10.5 g");
    await page.keyboard.press("Escape");
  });

  await test.step("the log dialog shows the portion, and follows an edited amount", async () => {
    await card(full).getByRole("button", { name: "Log" }).click();
    // The dialog opens on half the recipe (2 servings): 50 g oats + 100 g apple.
    await expect(page.getByTestId("log-fiber-sugar")).toHaveText("Fibre 7.4 g · Sugar 10.5 g");
  });
});
