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
