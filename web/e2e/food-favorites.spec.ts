import { test, expect, type APIRequestContext } from "@playwright/test";

/**
 * Favourite foods (LIF-147): the API stores the mark and an update from a client that knows nothing about it keeps it; the foods
 * table shows a star, filters to the starred ones and flips the mark from the row menu; the editor has a switch; and the add-food
 * dialog's Favorites filter lists a favourite food next to the favourite recipes.
 *
 * Requires the real backend + Postgres on localhost:8080/5432, same as the other specs in this folder.
 */

const API_BASE = "http://localhost:8080/api/v1";
const PASSWORD = "E2eFavorite123!";

async function registerAndLogin(request: APIRequestContext, email: string) {
  const registerRes = await request.post(`${API_BASE}/auth/register`, { data: { email, password: PASSWORD, firstName: "E2E", lastName: "Favorite" } });
  expect(registerRes.ok(), await registerRes.text()).toBeTruthy();
  const loginRes = await request.post(`${API_BASE}/auth/login`, { data: { email, password: PASSWORD } });
  expect(loginRes.ok(), await loginRes.text()).toBeTruthy();
  return (await loginRes.json()).accessToken as string;
}

test("favourite foods: stored by the API, starred in the table, flipped from the menu and the editor, listed under Favorites", async ({ page, request }) => {
  const runId = Date.now();
  const email = `e2e-favorite-${runId}@example.com`;
  const token = await registerAndLogin(request, email);
  const auth = { Authorization: `Bearer ${token}` };
  const star = `Skyr ${runId}`;
  const plain = `Rice ${runId}`;
  const ids: Record<string, number> = {};

  const favorite = async (name: string) => {
    const list: Array<{ id: number; name: string; favorite: boolean }> = await (await request.get(`${API_BASE}/foods`, { headers: auth })).json();
    return list.find((f) => f.id === ids[name])!.favorite;
  };

  await test.step("the API stores the mark, and an update without the field keeps it", async () => {
    for (const [name, fav] of [[star, true], [plain, undefined]] as const) {
      const res = await request.post(`${API_BASE}/foods`, {
        headers: auth,
        data: { name, caloriesPer100g: 60, proteinPer100g: 11, hidden: false, ...(fav ? { favorite: true } : {}) },
      });
      expect(res.ok(), await res.text()).toBeTruthy();
      ids[name] = (await res.json()).id;
    }
    expect(await favorite(star)).toBe(true);
    expect(await favorite(plain)).toBe(false);

    const ordinary = await request.put(`${API_BASE}/foods/${ids[star]}`, { headers: auth, data: { name: star, caloriesPer100g: 61, proteinPer100g: 11, hidden: false } });
    expect(ordinary.ok(), await ordinary.text()).toBeTruthy();
    expect(await favorite(star)).toBe(true);
  });

  await page.goto("/login");
  await page.getByPlaceholder("you@example.com").fill(email);
  await page.getByPlaceholder("••••••••").fill(PASSWORD);
  await page.getByRole("button", { name: "Sign in" }).click();
  await page.waitForURL(/dashboard|onboarding/);

  await test.step("the table stars the favourite and the Favorites chip narrows it", async () => {
    await page.goto("/nutrition?tab=foods");
    const starRow = page.getByRole("row").filter({ hasText: star });
    const plainRow = page.getByRole("row").filter({ hasText: plain });
    await expect(starRow.getByLabel("Favorite")).toBeVisible();
    await expect(plainRow.getByLabel("Favorite")).toHaveCount(0);

    const chip = page.getByTestId("foods-table").getByRole("button", { name: "Favorites" });
    await chip.click();
    await expect(chip).toHaveAttribute("aria-pressed", "true");
    await expect(starRow).toBeVisible();
    await expect(plainRow).toHaveCount(0);
    await chip.click();
    await expect(plainRow).toBeVisible();
  });

  await test.step("the row menu adds and removes the star", async () => {
    const plainRow = page.getByRole("row").filter({ hasText: plain });
    await plainRow.getByRole("button", { name: /Actions for/ }).click();
    await page.getByRole("menuitem", { name: "Add to favorites" }).click();
    await expect.poll(() => favorite(plain)).toBe(true);
    await expect(plainRow.getByLabel("Favorite")).toBeVisible();

    await plainRow.getByRole("button", { name: /Actions for/ }).click();
    await page.getByRole("menuitem", { name: "Remove from favorites" }).click();
    await expect.poll(() => favorite(plain)).toBe(false);
    await expect(plainRow.getByLabel("Favorite")).toHaveCount(0);
  });

  await test.step("the editor's switch sets and clears the star", async () => {
    const plainRow = page.getByRole("row").filter({ hasText: plain });
    await plainRow.getByRole("button", { name: /Actions for/ }).click();
    await page.getByRole("menuitem", { name: "Edit" }).click();
    const editor = page.getByTestId("food-editor");
    const toggle = editor.getByRole("switch", { name: "Favorite" });
    await expect(toggle).toHaveAttribute("aria-checked", "false");
    await toggle.click();
    await editor.getByRole("button", { name: "Save" }).click();
    await expect.poll(() => favorite(plain)).toBe(true);

    await plainRow.getByRole("button", { name: /Actions for/ }).click();
    await page.getByRole("menuitem", { name: "Edit" }).click();
    await expect(page.getByTestId("food-editor").getByRole("switch", { name: "Favorite" })).toHaveAttribute("aria-checked", "true");
    await page.getByTestId("food-editor").getByRole("switch", { name: "Favorite" }).click();
    await page.getByTestId("food-editor").getByRole("button", { name: "Save" }).click();
    await expect.poll(() => favorite(plain)).toBe(false);
  });

  await test.step("the add-food dialog's Favorites filter lists the favourite food, not the others", async () => {
    await page.goto("/nutrition");
    await page.getByRole("button", { name: /Add food/ }).first().click();
    await page.getByRole("group", { name: "Filter results" }).getByRole("button", { name: "Favourites" }).click();
    const options = page.getByRole("option");
    await expect(options.filter({ hasText: star })).toHaveCount(1);
    await expect(options.filter({ hasText: star }).getByLabel("Favorite")).toBeVisible();
    await expect(options.filter({ hasText: plain })).toHaveCount(0);
  });
});
