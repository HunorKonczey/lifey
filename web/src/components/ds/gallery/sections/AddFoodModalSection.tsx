"use client";

import { useEffect, useMemo, useState, useSyncExternalStore } from "react";
import { Button } from "@/components/ds";
import { AddFoodModalView } from "@/features/nutrition/components/addFood/AddFoodModal";
import { FoodPreviewPaneView } from "@/features/nutrition/components/addFood/FoodPreviewPane";
import { buildSearchItems, type ItemUsage } from "@/features/nutrition/foodSearch";
import { isOffSearchable, offItemToSearchItem, offSearchEnabled, sanitizeOffQuery } from "@/features/nutrition/offSearch";
import type { FoodResponse, OffSearchItem, OffSearchResponse, RecipeResponse } from "@/features/nutrition/types";
import type { UseOffSearchResult } from "@/features/nutrition/useOffSearch";
import { useDebouncedValue } from "@/lib/hooks/useDebouncedValue";
import { normalizeForSearch } from "@/lib/utils/search";

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

// ── OpenFoodFacts fixture (docs/84): the gallery has no backend, so the option's hook is replaced by canned answers. ──
const off = (barcode: string, name: string, brand: string | null, kcal: number, protein: number, carbs: number | null, fat: number | null): OffSearchItem => ({
  barcode, name, brand, caloriesPer100g: kcal, proteinPer100g: protein, carbsPer100g: carbs, fatPer100g: fat,
});
const OFF_FIXTURE = [
  off("4056489827702", "Csirkemell", "Pikok", 110, 14, 2.4, 4.9),
  off("5999033874557", "Csirkemell sonka", "S-Budget", 109, 15, 2, 4.5),
  off("5998202960657", "Rántott csirkemell", "Nádudvari", 196, 10.6, null, null),
  off("5997000000001", "Túró Rudi", null, 400, 11, 33, 25),
  off("5711953000013", "Skyr vaníliás", "Arla", 66, 11, 5, 0.2),
];
const OFF_ENGLISH_FIXTURE = [off("0722252601025", "Pumpkin puree", "Libby's", 34, 1.1, 8, 0.1)];

/** Magic words give the e2e tests every state: slowpoke → still loading, boom → the request failed, unavail / limited → the statuses, pumpkin → the English fallback, nothing → empty. */
function offAnswer(text: string): OffSearchResponse {
  const base = { language: "hu" as const, fellBackToEnglish: false, items: [] as OffSearchItem[] };
  if (text === "unavail") return { ...base, status: "UNAVAILABLE" };
  if (text === "limited") return { ...base, status: "RATE_LIMITED" };
  if (text === "pumpkin") return { status: "OK", language: "en", fellBackToEnglish: true, items: OFF_ENGLISH_FIXTURE };
  const q = normalizeForSearch(text);
  return { ...base, status: "OK", items: OFF_FIXTURE.filter((i) => normalizeForSearch(i.name).includes(q)) };
}

// Every request the fixture "would make", so a test can show that an unticked box makes none.
const requests: string[] = [];
const listeners = new Set<() => void>();
const subscribeRequests = (l: () => void) => (listeners.add(l), () => void listeners.delete(l));
const requestCount = () => requests.length;
function recordRequest(text: string) {
  requests.push(text);
  listeners.forEach((l) => l());
}

const IDLE: UseOffSearchResult = { active: false, pending: false, items: [], response: undefined, failed: false };

function useFixtureOff({ query, checked }: { query: string; checked: boolean }): UseOffSearchResult {
  const text = sanitizeOffQuery(query);
  // The same shape as the real hook: debounced, so typing a word is one "request".
  const settled = useDebouncedValue(text, 150);
  const active = offSearchEnabled(checked, text, settled);
  useEffect(() => {
    if (active) recordRequest(settled);
  }, [active, settled]);
  const settling = checked && isOffSearchable(text) && text !== settled;
  if (!active) return { ...IDLE, pending: settling };
  if (settled === "slowpoke") return { ...IDLE, active: true, pending: true };
  if (settled === "boom") return { ...IDLE, active: true, pending: settling, failed: true };
  const response = offAnswer(settled);
  return { active: true, pending: settling, items: response.items.map(offItemToSearchItem), response, failed: false };
}

/**
 * The add-food dialog (W2.5 + W2.6) on fixture data: the search pane, the
 * preview pane (macros, "left after this", meal type) and the submit, which here
 * only logs what would be added (the dialog stays open, like the real one). Type, ↓, Tab, a quantity, Enter.
 */
function readGalleryPreference(): boolean {
  try {
    return window.localStorage.getItem("lifey.addFood.offSearch") === "1";
  } catch {
    return false;
  }
}

export function AddFoodModalSection() {
  const [open, setOpen] = useState(false);
  const [added, setAdded] = useState<string[]>([]);
  const [created, setCreated] = useState<string | null>(null);
  const offRequests = useSyncExternalStore(subscribeRequests, requestCount, requestCount);
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
          onOffCheckedChange={(on) => {
            try {
              window.localStorage.setItem("lifey.addFood.offSearch", on ? "1" : "0");
            } catch {
              /* the gallery just does not remember */
            }
          }}
          initialOffChecked={readGalleryPreference()}
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
