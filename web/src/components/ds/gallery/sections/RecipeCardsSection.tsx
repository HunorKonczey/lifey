"use client";

import { useState } from "react";
import { LogRecipeModal } from "@/features/nutrition/components/LogRecipeDialog";
import { RecipeCard } from "@/features/nutrition/components/RecipeCard";
import type { Macros } from "@/features/nutrition/recipeMacros";
import type { FoodResponse, RecipeResponse } from "@/features/nutrition/types";

const ing = (foodId: number, foodName: string, quantityInGrams: number, calories: number, protein: number) => ({
  foodId,
  foodName,
  quantityInGrams,
  calories,
  protein,
});

const recipe = (id: number, name: string, servings: number, favorite: boolean, ingredients: RecipeResponse["ingredients"]): RecipeResponse => ({
  id,
  name,
  description: null,
  favorite,
  servings,
  ingredients,
  imageUpdatedAt: null,
});

const fill = (n: number) => Array.from({ length: n }, (_, i) => ing(100 + i, `Hozzávaló ${i + 1}`, 100, 100, 5));

const RICE_BOWL = recipe(1, "Csirkés rizstál brokkolival", 4, true, [
  ing(1, "Csirkemell", 600, 990, 186),
  ing(2, "Barna rizs", 480, 590, 13),
  ing(3, "Brokkoli", 360, 122, 10),
]);

const CARDS: { recipe: RecipeResponse; perServing: Macros }[] = [
  // carbs carry the most kcal: 38 P = 152, 58 C = 232, 14 F = 126
  { recipe: { ...RICE_BOWL, ingredients: [...RICE_BOWL.ingredients, ...fill(2)] }, perServing: { calories: 528, protein: 38, carbs: 58, fat: 14 } },
  // protein: 32 P = 128, 30 C = 120, 12 F = 108
  { recipe: recipe(2, "Görög joghurtos zabkása", 2, false, fill(3)), perServing: { calories: 380, protein: 32, carbs: 30, fat: 12 } },
  // fat: 10 P = 40, 30 C = 120, 30 F = 270
  { recipe: recipe(3, "Avokádós pirítós tojással és egy nagyon hosszú névvel, ami két sorba kerül", 1, false, fill(4)), perServing: { calories: 450, protein: 10, carbs: 30, fat: 30 } },
  // nothing known about the macros: the neutral icon
  { recipe: recipe(4, "Házi leves", 6, false, fill(1)), perServing: { calories: 120, protein: 0, carbs: 0, fat: 0 } },
];

const FOODS: FoodResponse[] = [
  { id: 1, name: "Csirkemell", caloriesPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6, barcode: null, hidden: false },
  { id: 2, name: "Barna rizs", caloriesPer100g: 123, proteinPer100g: 2.7, carbsPer100g: 25.6, fatPer100g: 1, barcode: null, hidden: false },
  { id: 3, name: "Brokkoli", caloriesPer100g: 34, proteinPer100g: 2.8, carbsPer100g: 6.6, fatPer100g: 0.4, barcode: null, hidden: false },
];
const FOODS_BY_ID = new Map(FOODS.map((f) => [f.id, f]));

/** Recipe cards (W2.11) in the four tints, and the log-recipe modal on the rice bowl; actions only log what they would do. */
export function RecipeCardsSection() {
  const [log, setLog] = useState("—");
  const [logging, setLogging] = useState(false);

  return (
    <div className="flex flex-col gap-4">
      <p data-testid="recipe-log" className="type-body-s">
        Last action: {log}
      </p>
      <div className="@container">
        <div className="grid grid-cols-1 gap-4 @[560px]:grid-cols-2 @[840px]:grid-cols-3" data-testid="recipe-cards">
          {CARDS.map(({ recipe: r, perServing }) => (
            <RecipeCard
              key={r.id}
              recipe={r}
              perServing={perServing}
              onOpen={() => setLog(`open ${r.id}`)}
              onLog={() => {
                setLog(`log ${r.id}`);
                if (r.id === 1) setLogging(true);
              }}
              menu={[
                { label: "Edit", icon: "edit", onSelect: () => setLog(`edit ${r.id}`) },
                { label: "Duplicate", icon: "content_copy", onSelect: () => setLog(`duplicate ${r.id}`) },
                { label: "Delete", icon: "delete", destructive: true, onSelect: () => setLog(`delete ${r.id}`) },
              ]}
            />
          ))}
        </div>
      </div>
      {logging && (
        <LogRecipeModal
          recipe={RICE_BOWL}
          foodsById={FOODS_BY_ID}
          initialMealType="LUNCH"
          onClose={() => setLogging(false)}
          onConfirm={({ mealType, entries }) => {
            setLog(`logged ${mealType}: ${entries.map((e) => `${e.foodId}:${e.quantityInGrams}`).join(",")}`);
            setLogging(false);
          }}
        />
      )}
    </div>
  );
}
