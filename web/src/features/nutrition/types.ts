export type MealType = "BREAKFAST" | "LUNCH" | "DINNER" | "SNACK";
export type BarcodeSource = "LOCAL" | "OPENFOODFACTS";

// ─── Foods ───
export interface FoodResponse {
  id: number;
  name: string;
  caloriesPer100g: number;
  proteinPer100g: number;
  carbsPer100g: number | null;
  fatPer100g: number | null;
  barcode: string | null;
  hidden: boolean;
}

export interface FoodRequest {
  name: string;
  caloriesPer100g: number;
  proteinPer100g: number;
  carbsPer100g: number;
  fatPer100g: number;
  barcode?: string | null;
  hidden: boolean;
}

export interface BarcodeLookupResponse {
  id: number | null;
  name: string;
  caloriesPer100g: number;
  proteinPer100g: number;
  carbsPer100g: number | null;
  fatPer100g: number | null;
  barcode: string;
  source: BarcodeSource;
}

// ─── OpenFoodFacts name search (docs/84) ───
export type OffSearchStatus = "OK" | "UNAVAILABLE" | "RATE_LIMITED";
/** The languages the backend searches in; it treats anything else as English. */
export type OffSearchLang = "hu" | "en";

/** A product found by name — not saved anywhere; it becomes a food when the user logs it. */
export interface OffSearchItem {
  barcode: string;
  name: string;
  brand: string | null;
  caloriesPer100g: number;
  proteinPer100g: number;
  carbsPer100g: number | null;
  fatPer100g: number | null;
}

export interface OffSearchResponse {
  /** Anything but OK comes with no items: an OpenFoodFacts problem is not an HTTP error. */
  status: OffSearchStatus;
  /** The language the items were searched in. */
  language: OffSearchLang;
  /** True only when the user's-language search found nothing and the English one did. */
  fellBackToEnglish: boolean;
  items: OffSearchItem[];
}

// ─── Meals ───
export interface MealEntryResponse {
  foodId: number;
  foodName: string;
  quantityInGrams: number;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
}

export interface MealResponse {
  id: number;
  dateTime: string; // Instant
  mealType: MealType;
  name: string | null;
  entries: MealEntryResponse[];
  /** The trainer's comment on this meal and when it was written (LIF-144); absent or null when uncommented. */
  trainerComment?: string | null;
  trainerCommentAt?: string | null;
}

export interface MealEntryRequest {
  foodId: number;
  quantityInGrams: number;
}

export interface MealRequest {
  dateTime: string; // Instant, must be past or present
  mealType: MealType;
  name?: string | null;
  entries: MealEntryRequest[];
}

// ─── Recipes ───
export interface RecipeIngredientResponse {
  foodId: number;
  foodName: string;
  quantityInGrams: number;
  calories: number;
  protein: number;
}

export interface RecipeResponse {
  id: number;
  name: string;
  description: string | null;
  favorite: boolean;
  servings: number;
  ingredients: RecipeIngredientResponse[];
  // Null if no photo is set. GET /recipes/{id}/image(/thumbnail) serves it.
  imageUpdatedAt: string | null;
  /** The trainer whose copy this is; absent or null for a recipe the user made themselves (LIF-104). */
  originTrainerId?: number | null;
}

export interface RecipeIngredientRequest {
  foodId: number;
  quantityInGrams: number;
}

export interface RecipeRequest {
  name: string;
  description?: string | null;
  favorite: boolean;
  servings: number;
  ingredients: RecipeIngredientRequest[];
}
