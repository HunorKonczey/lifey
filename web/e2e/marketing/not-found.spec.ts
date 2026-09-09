import { test, expect } from "@playwright/test";

/**
 * The branded 404 (docs/landing_page/72 Prompt 1, D-F1). Two separate pages
 * answer four different shapes of wrong URL, and the status code matters as
 * much as the copy: a 404 page served with 200 is a soft-404, which is worse
 * than the ugly default it replaces (65 §3.3).
 */

test.describe("marketing 404", () => {
  test("an unmatched path under a known locale renders the localized page inside the shell", async ({
    page,
  }) => {
    const response = await page.goto("/hu/nincs-ilyen-oldal");

    expect(response?.status()).toBe(404);
    await expect(page.getByRole("heading", { name: "Ez az oldal nincs meg", level: 1 })).toBeVisible();
    // Inside the marketing shell: the header nav and the footer are both here,
    // which is the whole point of the nested boundary.
    await expect(page.getByRole("navigation").getByRole("link", { name: "Edzőknek" })).toBeVisible();
    await expect(page.locator("#site-footer")).toBeVisible();

    await page.getByRole("link", { name: "Vissza a főoldalra" }).click();
    await expect(page).toHaveURL(/\/hu$/);
  });

  test("the English locale gets English copy and its own pricing link", async ({ page }) => {
    const response = await page.goto("/en/nope");

    expect(response?.status()).toBe(404);
    await expect(page.getByRole("heading", { name: "This page doesn't exist", level: 1 })).toBeVisible();

    await page.getByRole("link", { name: "See pricing" }).click();
    await expect(page).toHaveURL(/\/en\/pricing$/);
  });

  test("an unknown locale falls to the root 404 in Hungarian, with no marketing chrome", async ({
    page,
  }) => {
    const response = await page.goto("/de/whatever");

    expect(response?.status()).toBe(404);
    await expect(page.getByRole("heading", { name: "Ez az oldal nincs meg", level: 1 })).toBeVisible();
    // The layout threw before its own boundary existed, so this is the root
    // page: no header nav, no footer.
    await expect(page.locator("#site-footer")).toHaveCount(0);
  });

  test("a path outside the marketing tree also gets the root 404", async ({ page }) => {
    const response = await page.goto("/random");

    expect(response?.status()).toBe(404);
    await expect(page.getByRole("heading", { name: "Ez az oldal nincs meg", level: 1 })).toBeVisible();
  });

  test("the chrome-free download page's own 404 is the marketing one, not a bare copy", async ({
    page,
  }) => {
    // `/hu/letoltes/anything` is matched by the catch-all in the `(marketing)`
    // group — `(marketing-bare)` has no catch-all of its own, so a bare 404 is
    // unreachable by construction and deliberately does not exist (72 §6).
    const response = await page.goto("/hu/letoltes/extra");

    expect(response?.status()).toBe(404);
    await expect(page.locator("#site-footer")).toBeVisible();
  });
});
