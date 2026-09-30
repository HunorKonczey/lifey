"use client";

import { useEffect, useMemo, useState } from "react";
import { Button } from "@/components/ds";
import { AddFoodModalView, useAddFoodContext } from "@/features/nutrition/components/addFood/AddFoodModal";
import { buildSearchItems, type ItemUsage } from "@/features/nutrition/foodSearch";
import type { FoodResponse, RecipeResponse } from "@/features/nutrition/types";

const food = (id: number, name: string, caloriesPer100g: number): FoodResponse => ({
  id,
  name,
  caloriesPer100g,
  proteinPer100g: 8,
  carbsPer100g: 10,
  fatPer100g: 3,
  barcode: null as unknown as string,
  hidden: false,
});

// A fixed moment, so the fixture never depends on the clock.
const LOGGED_AT = new Date(2026, 8, 29, 8, 0).getTime();

const FOODS = [
  food(1, "Görög joghurt 2%", 73),
  food(2, "Natúr joghurt 3,5%", 61),
  food(3, "Joghurt 10%", 133),
  food(4, "Skyr natúr", 63),
  food(5, "Kefir", 52),
  food(6, "Barna rizs (főtt)", 123),
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

/** The add-food dialog shell (W2.5) with fixture data and a stub preview: type, ↓, Tab, a quantity, Enter. */
export function AddFoodModalSection() {
  const [open, setOpen] = useState(false);
  const [added, setAdded] = useState<string[]>([]);
  const [created, setCreated] = useState<string | null>(null);
  const items = useMemo(() => buildSearchItems(FOODS, RECIPES), []);
  const usage = useMemo(
    () =>
      new Map<string, ItemUsage>([
        ["food:5", { lastUsedAt: LOGGED_AT + 3_600_000, useCount: 3 }], // Kefir — logged most recently
        ["food:1", { lastUsedAt: LOGGED_AT, useCount: 1 }],
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
      <AddFoodModalView
        open={open}
        onClose={() => setOpen(false)}
        items={items}
        usage={usage}
        onCreate={(name) => {
          setCreated(name);
          setOpen(false);
        }}
      >
        <StubPreview
          onAdd={(label) => {
            setAdded((a) => [...a, label]);
            setOpen(false);
          }}
        />
      </AddFoodModalView>
    </div>
  );
}

/** Stands in for W2.6's preview pane: shows the active row and a quantity box that Tab reaches. */
function StubPreview({ onAdd }: { onAdd: (label: string) => void }) {
  const ctx = useAddFoodContext();
  const [qty, setQty] = useState("100");
  const { active, setCommit } = ctx;
  useEffect(() => {
    setCommit(() => active && onAdd(`${active.name} ${qty} g`));
    return () => setCommit(null);
  });

  return (
    <div className="flex flex-col gap-3">
      <h3 data-testid="preview-title" className="type-title-l">
        {active?.name ?? "—"}
      </h3>
      <input
        ref={(el) => ctx.registerQuantity(el)}
        aria-label="Quantity (g)"
        value={qty}
        onChange={(e) => setQty(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Enter") {
            e.preventDefault();
            if (active) onAdd(`${active.name} ${qty} g`);
          }
        }}
        className="h-10 w-28 px-3"
        style={{ background: "var(--nested)", borderRadius: "var(--r-control)" }}
      />
    </div>
  );
}
