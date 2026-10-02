import { z } from "zod";

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

export type RecipeFormValues = z.infer<typeof recipeSchema>;
