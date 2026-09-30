import { test, expect } from "./fixtures";

/** Modal/Sheet/ConfirmModal (D-W0.12) against the gallery's "Modal & confirm"
 *  section: focus trap, Esc, focus return, scroll lock, and the mobile
 *  Sheet shape at 390px.
 *
 *  Dialogs are scoped by accessible name throughout — the "Date picker"
 *  section's `CalendarPopover` demo is open by default and is itself a
 *  `role="dialog"`, so a bare `getByRole("dialog")` matches two elements. */

test.beforeEach(async ({ page }) => {
  await page.goto("/dev/design");
  await page.getByRole("heading", { name: "Modal & confirm", exact: true }).scrollIntoViewIfNeeded();
});

test("opens on click and traps focus, wrapping Tab within the dialog", async ({ page }) => {
  await page.getByRole("button", { name: "Open modal" }).click();
  const dialog = page.getByRole("dialog", { name: "Sample modal" });
  await expect(dialog).toBeVisible();
  await expect(dialog.getByRole("button", { name: "Close" })).toBeFocused();
  // Only one focusable element inside — Tab keeps landing back on it.
  await page.keyboard.press("Tab");
  await expect(dialog.getByRole("button", { name: "Close" })).toBeFocused();
  await page.keyboard.press("Shift+Tab");
  await expect(dialog.getByRole("button", { name: "Close" })).toBeFocused();
});

test("Esc closes the modal and returns focus to the trigger", async ({ page }) => {
  const trigger = page.getByRole("button", { name: "Open modal" });
  await trigger.click();
  await expect(page.getByRole("dialog", { name: "Sample modal" })).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(page.getByRole("dialog", { name: "Sample modal" })).toHaveCount(0);
  await expect(trigger).toBeFocused();
});

test("body scroll is locked while the modal is open", async ({ page }) => {
  await page.getByRole("button", { name: "Open modal" }).click();
  await expect(page.getByRole("dialog", { name: "Sample modal" })).toBeVisible();
  await expect(page.locator("body")).toHaveCSS("overflow", "hidden");
  await page.keyboard.press("Escape");
  await expect(page.getByRole("dialog", { name: "Sample modal" })).toHaveCount(0);
  await expect(page.locator("body")).not.toHaveCSS("overflow", "hidden");
});

test("an outside click (scrim) closes the modal", async ({ page }) => {
  await page.getByRole("button", { name: "Open modal" }).click();
  await expect(page.getByRole("dialog", { name: "Sample modal" })).toBeVisible();
  await page.mouse.click(10, 10);
  await expect(page.getByRole("dialog", { name: "Sample modal" })).toHaveCount(0);
});

test("the confirm modal focuses the safe (cancel) button, never the destructive one", async ({ page }) => {
  await page.getByRole("button", { name: "Open confirm" }).click();
  const dialog = page.getByRole("dialog", { name: "Delete this entry?" });
  await expect(dialog).toBeVisible();
  await expect(dialog.getByRole("button", { name: "Cancel" })).toBeFocused();
});

test("confirming the destructive action closes the modal and runs onConfirm", async ({ page }) => {
  await page.getByRole("button", { name: "Open confirm" }).click();
  const dialog = page.getByRole("dialog", { name: "Delete this entry?" });
  await dialog.getByRole("button", { name: "Delete", exact: true }).click();
  await expect(dialog).toHaveCount(0);
  await expect(page.getByText("Confirmed.")).toBeVisible();
});

test("cancelling the confirm modal leaves the entry alone", async ({ page }) => {
  await page.getByRole("button", { name: "Open confirm" }).click();
  const dialog = page.getByRole("dialog", { name: "Delete this entry?" });
  await dialog.getByRole("button", { name: "Cancel" }).click();
  await expect(dialog).toHaveCount(0);
  await expect(page.getByText("Confirmed.")).toHaveCount(0);
});

test("under 768px the modal renders as a bottom sheet", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.getByRole("button", { name: "Open modal" }).click();
  const dialog = page.getByRole("dialog", { name: "Sample modal" });
  await expect(dialog).toBeVisible();
  await page.waitForTimeout(450); // let the 350ms slide-up (--dur-sheet) settle
  const box = await dialog.boundingBox();
  const viewport = page.viewportSize()!;
  // A sheet is pinned to the bottom edge and spans the full width.
  expect(box!.width).toBeCloseTo(viewport.width, 0);
  expect(box!.y + box!.height).toBeCloseTo(viewport.height, 0);
});
