import { z } from "zod";

export const foodSchema = z.object({
  name: z.string().min(1, "Name is required"),
  caloriesPer100g: z.number({ message: "Required" }).min(0, "Must be ≥ 0"),
  proteinPer100g: z.number({ message: "Required" }).min(0, "Must be ≥ 0"),
  carbsPer100g: z.number({ message: "Required" }).min(0, "Must be ≥ 0"),
  fatPer100g: z.number({ message: "Required" }).min(0, "Must be ≥ 0"),
  barcode: z.string().optional().nullable(),
  hidden: z.boolean(),
});

export const recipeSchema = z.object({
  name: z.string().min(1, "Name is required"),
  description: z.string().optional().nullable(),
  favorite: z.boolean(),
  servings: z.coerce.number().int().positive("Must be at least 1"),
  ingredients: z
    .array(
      z.object({
        foodId: z.number(),
        quantityInGrams: z.coerce.number().positive("Must be > 0"),
      }),
    )
    .min(1, "Add at least one ingredient"),
});

export type FoodFormValues = z.infer<typeof foodSchema>;
export type RecipeFormValues = z.infer<typeof recipeSchema>;
