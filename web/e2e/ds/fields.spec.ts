import { test, expect } from "@playwright/test";

/** Form fields (D-W0.9) against the gallery's "Fields" section: every field
 *  has a label, an error is wired to its input via aria-describedby, and the
 *  number field's steppers/arrow keys actually change its value. */

test.beforeEach(async ({ page }) => {
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Fields", exact: true }).scrollIntoViewIfNeeded();
});

test("every field's label is programmatically associated with its input", async ({ page }) => {
  for (const name of ["Name", "Password", "Notes"]) {
    await expect(page.getByLabel(name, { exact: true })).toBeVisible();
  }
});

test("an error message is wired to its input via aria-describedby", async ({ page }) => {
  const input = page.getByLabel("With an error", { exact: true });
  const describedBy = await input.getAttribute("aria-describedby");
  expect(describedBy).not.toBeNull();
  await expect(page.locator(`#${describedBy}`)).toHaveText("Legalább 8 karakter kell (most 6).");
  await expect(input).toHaveAttribute("aria-invalid", "true");
});

test("a disabled field cannot be typed into", async ({ page }) => {
  await expect(page.getByLabel("Disabled", { exact: true })).toBeDisabled();
});

test("the number field's steppers and arrow keys change its value by step", async ({ page }) => {
  const input = page.getByLabel("Protein", { exact: true });
  await expect(input).toHaveValue("166.7");

  await page.getByRole("button", { name: "Increase" }).click();
  await expect(input).toHaveValue("166.8");

  await page.getByRole("button", { name: "Decrease" }).click();
  await page.getByRole("button", { name: "Decrease" }).click();
  await expect(input).toHaveValue("166.6");

  await input.focus();
  await page.keyboard.press("ArrowUp");
  await expect(input).toHaveValue("166.7");
  await page.keyboard.press("Shift+ArrowUp");
  await expect(input).toHaveValue("167.7");
});

test("the read-only field renders plain text, not a field shape", async ({ page }) => {
  await expect(page.getByText("Kliens · csak olvasható")).toBeVisible();
  // No input/textbox role for the read-only value.
  await expect(page.getByRole("textbox", { name: "Client" })).toHaveCount(0);
});
