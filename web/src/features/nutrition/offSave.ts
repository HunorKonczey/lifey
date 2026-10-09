import type { FoodRequest, FoodResponse, OffSearchItem } from "./types";

/**
 * Turning an OpenFoodFacts result into one of the user's own foods when they log it (docs/84 D8, Prompt 7).
 * Pure and given the two API calls it needs, so the awkward cases — the same product or name already there — are
 * tested without a backend.
 */
export interface FoodWriter {
  create: (body: FoodRequest) => Promise<FoodResponse>;
  list: () => Promise<FoodResponse[]>;
}

/** The food to create for a result: per-100 g macros, a missing carbs or fat as 0 (like the barcode flow), kept visible. */
export function offFoodRequest(item: OffSearchItem, name: string = item.name, withBarcode = true): FoodRequest {
  return {
    name: name.trim(),
    caloriesPer100g: item.caloriesPer100g,
    proteinPer100g: item.proteinPer100g,
    carbsPer100g: item.carbsPer100g ?? 0,
    fatPer100g: item.fatPer100g ?? 0,
    // Fibre and sugars stay unknown when OpenFoodFacts has none - unlike carbs and fat they are not counted as 0.
    ...(item.fiberPer100g != null ? { fiberPer100g: item.fiberPer100g } : {}),
    ...(item.sugarPer100g != null ? { sugarPer100g: item.sugarPer100g } : {}),
    barcode: withBarcode ? item.barcode : null,
    hidden: false,
  };
}

/** "Csirkemell (Pikok)", or "Csirkemell (OpenFoodFacts)" without a brand: tells a product from the user's own food of the same name. */
export function disambiguatedName(item: OffSearchItem): string {
  return `${item.name.trim()} (${item.brand?.trim() || "OpenFoodFacts"})`;
}

function isConflict(error: unknown): boolean {
  return typeof error === "object" && error !== null && (error as { status?: unknown }).status === 409;
}

/**
 * The user's own food for this product, creating it if needed. The backend answers 409 for two different reasons and
 * both are expected here, so a 409 is walked through rather than shown:
 *
 * 1. create it as it is;
 * 2. 409 → perhaps the user already has this barcode (saved earlier on another device or since the search): use that food;
 * 3. else the *name* is taken by a different food: create it as "Name (Brand)";
 * 4. 409 again → the barcode is still held, by a deleted food (the `(user, barcode)` index keeps it): create it without the
 *    barcode, which loses nothing the app uses.
 *
 * Anything that is not a 409 (a failed request, a server error) is thrown at once — retrying it under another name would
 * hide a real problem. A 409 on the last step is thrown too.
 */
export async function ensureOwnFood(item: OffSearchItem, api: FoodWriter): Promise<FoodResponse> {
  try {
    return await api.create(offFoodRequest(item));
  } catch (error) {
    if (!isConflict(error)) throw error;
  }

  const existing = (await api.list()).find((food) => food.barcode === item.barcode);
  if (existing) return existing;

  const renamed = disambiguatedName(item);
  try {
    return await api.create(offFoodRequest(item, renamed));
  } catch (error) {
    if (!isConflict(error)) throw error;
  }

  return api.create(offFoodRequest(item, renamed, false));
}
