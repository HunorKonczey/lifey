import { test, expect } from "@playwright/test";

/**
 * The contact form's three states (docs/landing_page/65 §12 and 72 Prompt 5).
 * `POST /api/v1/contact` is stubbed rather than hit for real: the backend
 * endpoint has its own tests (65 Prompt 8), and what is unverified here is the
 * form's own state machine — including the error path, which a real backend
 * would not produce on demand.
 */

const CONTACT_ENDPOINT = "**/api/v1/contact";

async function fillForm(page: import("@playwright/test").Page) {
  await page.getByLabel("Név").fill("Teszt Elek");
  await page.getByLabel("E-mail").fill("teszt@example.com");
  await page.getByLabel("Üzenet").fill("Kérdésem lenne az árakról.");
}

test("a successful submit replaces the form with the confirmation", async ({ page }) => {
  await page.route(CONTACT_ENDPOINT, (route) => route.fulfill({ status: 204 }));

  await page.goto("/hu/kapcsolat");
  await fillForm(page);

  const request = page.waitForRequest(
    (r) => r.url().includes("/contact") && r.method() === "POST"
  );
  await page.getByRole("button", { name: "Küldés" }).click();

  // The locale travels with the message so the reply is written in the
  // language the visitor was reading (65 Prompt 8).
  expect((await request).postDataJSON()).toMatchObject({
    email: "teszt@example.com",
    locale: "hu",
  });
  await expect(page.getByText("Köszönjük! Hamarosan válaszolunk.")).toBeVisible();
  await expect(page.getByRole("button", { name: "Küldés" })).toHaveCount(0);
});

test("the button shows the sending state and is disabled while in flight", async ({ page }) => {
  let release: () => void = () => {};
  const held = new Promise<void>((resolve) => {
    release = resolve;
  });
  await page.route(CONTACT_ENDPOINT, async (route) => {
    await held;
    await route.fulfill({ status: 204 });
  });

  await page.goto("/hu/kapcsolat");
  await fillForm(page);
  await page.getByRole("button", { name: "Küldés" }).click();

  const sending = page.getByRole("button", { name: "Küldés…" });
  await expect(sending).toBeVisible();
  await expect(sending).toBeDisabled();

  release();
  await expect(page.getByText("Köszönjük! Hamarosan válaszolunk.")).toBeVisible();
});

test("a server error keeps the typed message and offers the direct email address", async ({
  page,
}) => {
  await page.route(CONTACT_ENDPOINT, (route) => route.fulfill({ status: 500, body: "boom" }));

  await page.goto("/hu/kapcsolat");
  await fillForm(page);
  await page.getByRole("button", { name: "Küldés" }).click();

  await expect(
    page.getByText("Nem sikerült elküldeni. Próbáld újra, vagy írj e-mailt közvetlenül.")
  ).toBeVisible();
  // Nothing typed is lost on failure — the form only resets on success.
  await expect(page.getByLabel("Üzenet")).toHaveValue("Kérdésem lenne az árakról.");
  // Scoped to `main`: the footer carries the same address in its contact column.
  await expect(page.getByRole("main").getByRole("link", { name: "hello@lifey.hu" })).toBeVisible();
});
