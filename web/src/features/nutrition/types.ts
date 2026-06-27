export type MealType = "BREAKFAST" | "LUNCH" | "DINNER" | "SNACK";

export interface MealEntryResponse {
  foodId: number;
  foodName: string;
  quantityInGrams: number;
  calories: number;
  protein: number;
}

export interface MealResponse {
  id: number;
  dateTime: string; // Instant
  mealType: MealType;
  name: string | null;
  entries: MealEntryResponse[];
}
