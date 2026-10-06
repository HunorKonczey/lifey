"use client";

import { useMemo, useState } from "react";
import { Button } from "@/components/ds";
import { AddFoodModalView } from "@/features/nutrition/components/addFood/AddFoodModal";
import { FoodPreviewPaneView } from "@/features/nutrition/components/addFood/FoodPreviewPane";
import { buildSearchItems, type ItemUsage } from "@/features/nutrition/foodSearch";
import type { FoodResponse, RecipeResponse } from "@/features/nutrition/types";
import { readGalleryOffPreference, useFixtureOff, useFixtureOffRequestCount, writeGalleryOffPreference } from "../offFixture";

const food = (id: number, name: string, kcal: number, protein: number, carbs: number, fat: number): FoodResponse => ({
  id,
  name,
  caloriesPer100g: kcal,
  proteinPer100g: protein,
  carbsPer100g: carbs,
  fatPer100g: fat,
  barcode: null as unknown as string,
  hidden: false,
});

// A fixed moment, so the fixture never depends on the clock.
const LOGGED_AT = new Date(2026, 8, 29, 8, 0).getTime();

const FOODS = [
  food(1, "Görög joghurt 2%", 73, 9.9, 3.9, 2),
  food(2, "Natúr joghurt 3,5%", 61, 3.5, 4.7, 3.5),
  food(3, "Joghurt 10%", 133, 3, 4, 10),
  food(4, "Skyr natúr", 63, 11, 4, 0.2),
  food(5, "Kefir", 52, 3.3, 4, 2.8),
  food(6, "Barna rizs (főtt)", 123, 2.7, 25.6, 1),
];
const RECIPES: RecipeResponse[] = [
  {
    id: 10,
    name: "Joghurtos zabkása",
    description: null,
    favorite: true,
    servings: 1,
    imageUpdatedAt: null,
    ingredients: [
      { foodId: 1, foodName: "Görög joghurt 2%", quantityInGrams: 200, calories: 146, protein: 20 },
      { foodId: 6, foodName: "Zabpehely", quantityInGrams: 60, calories: 266, protein: 8 },
    ],
  },
];

/**
 * The add-food dialog (W2.5 + W2.6) on fixture data: the search pane, the
 * preview pane (macros, "left after this", meal type) and the submit, which here
 * only logs what would be added (the dialog stays open, like the real one). Type, ↓, Tab, a quantity, Enter.
 */
export function AddFoodModalSection() {
  const [open, setOpen] = useState(false);
  const [added, setAdded] = useState<string[]>([]);
  const [created, setCreated] = useState<string | null>(null);
  const offRequests = useFixtureOffRequestCount();
  const items = useMemo(() => buildSearchItems(FOODS, RECIPES), []);
  const foodsById = useMemo(() => new Map(FOODS.map((f) => [f.id, f] as const)), []);
  const usage = useMemo(
    () =>
      new Map<string, ItemUsage>([
        ["food:5", { lastUsedAt: LOGGED_AT + 3_600_000, useCount: 3, lastGrams: 200 }], // Kefir — logged most recently
        ["food:1", { lastUsedAt: LOGGED_AT, useCount: 1, lastGrams: 150 }],
      ]),
    [],
  );

  return (
    <div className="flex flex-col gap-3">
      <Button onClick={() => setOpen(true)} data-testid="open-add-food">
        Open the add-food dialog
      </Button>
      <p data-testid="added-log" className="type-body-s">
        Added: {added.join(", ") || "—"}
      </p>
      <p data-testid="created-log" className="type-body-s">
        Create: {created ?? "—"}
      </p>
      <p data-testid="off-requests" className="type-body-s">
        OpenFoodFacts requests: {offRequests}
      </p>
      {open && (
        <AddFoodModalView
          open
          onClose={() => setOpen(false)}
          items={items}
          usage={usage}
          useOff={useFixtureOff}
          onOffCheckedChange={writeGalleryOffPreference}
          initialOffChecked={readGalleryOffPreference()}
          onCreate={(name) => {
            setCreated(name);
            setOpen(false);
          }}
        >
          <FoodPreviewPaneView
            foodsById={foodsById}
            initialMealType="DINNER"
            consumed={{ calories: 1041, protein: 68 }}
            goals={{ dailyCalorieGoal: 1900, dailyProteinGoal: 120 }}
            onSubmit={(req) => {
              // The real dialog stays open after an add; so does this one.
              const what =
                req.kind === "macros"
                  ? `${req.entry.name || "Custom entry"} ${req.entry.totals.calories} kcal / ${req.entry.grams} g`
                  : `${req.item.name} ${req.quantity} ${req.item.kind === "recipe" ? "servings" : "g"}`;
              setAdded((a) => [...a, `${what} ${req.mealType}`]);
            }}
            onDone={() => setOpen(false)}
          />
        </AddFoodModalView>
      )}
    </div>
  );
}
