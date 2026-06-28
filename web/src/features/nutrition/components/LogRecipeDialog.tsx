"use client";

import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { format } from "date-fns";
import { mealApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { logTimestampFor } from "@/lib/utils/logTime";
import type { RecipeResponse, MealType } from "../types";

const MEAL_TYPES: { value: MealType; label: string }[] = [
  { value: "BREAKFAST", label: "Breakfast" },
  { value: "LUNCH", label: "Lunch" },
  { value: "DINNER", label: "Dinner" },
  { value: "SNACK", label: "Snack" },
];

/** Pick a sensible default meal type based on the current hour (mirrors mobile). */
function defaultMealType(): MealType {
  const h = new Date().getHours();
  if (h < 11) return "BREAKFAST";
  if (h < 15) return "LUNCH";
  if (h < 21) return "DINNER";
  return "SNACK";
}

/**
 * Log a whole recipe as a meal: its ingredients become the meal's entries.
 * Optionally split into portions (defaults to the recipe's serving count), so
 * logging one serving divides every ingredient's grams by the portion count.
 */
export function LogRecipeDialog({
  recipe, date, onClose,
}: {
  recipe: RecipeResponse;
  date: Date;
  onClose: () => void;
}) {
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [mealType, setMealType] = useState<MealType>(defaultMealType());
  const [partial, setPartial] = useState(recipe.servings > 1);
  const [divisor, setDivisor] = useState(Math.min(Math.max(recipe.servings, 1), 20));

  const effDivisor = partial ? divisor : 1;
  const totalKcal = recipe.ingredients.reduce((s, i) => s + i.calories, 0);
  const totalProtein = recipe.ingredients.reduce((s, i) => s + i.protein, 0);

  const mutation = useMutation({
    mutationFn: () => {
      return mealApi.create({
        dateTime: logTimestampFor(date),
        mealType,
        name: recipe.name,
        entries: recipe.ingredients.map((i) => ({
          foodId: i.foodId,
          quantityInGrams: Math.round((i.quantityInGrams / effDivisor) * 100) / 100,
        })),
      });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.meals.all() });
      show(`Logged ${recipe.name}`, "success");
      onClose();
    },
    onError: () => show("Failed to log recipe", "error"),
  });

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center p-4"
      style={{ background: "rgba(0,0,0,.5)" }} onClick={onClose}>
      <div className="w-full max-w-md rounded-[var(--r-lg)] p-5 flex flex-col gap-4"
        style={{ background: "var(--surface)" }} onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between">
          <div>
            <h3 className="font-bold text-base">Log as meal</h3>
            <p className="text-xs" style={{ color: "var(--muted)" }}>
              {recipe.name} · {recipe.ingredients.length} ingredients
            </p>
          </div>
          <button onClick={onClose} aria-label="Close" className="p-1 rounded-[var(--r-sm)]">
            <span className="material-symbols-rounded">close</span>
          </button>
        </div>

        {/* Meal type */}
        <div className="flex flex-col gap-1.5">
          <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>Meal</label>
          <div className="flex flex-wrap gap-2">
            {MEAL_TYPES.map((m) => (
              <button key={m.value} onClick={() => setMealType(m.value)}
                className="px-3 h-8 rounded-[var(--r-pill)] text-xs font-semibold transition-colors"
                style={{
                  background: mealType === m.value ? "var(--primary)" : "var(--surface-container)",
                  color: mealType === m.value ? "#1E1F18" : "var(--on-surface-variant)",
                  border: "1px solid var(--outline)",
                }}>
                {m.label}
              </button>
            ))}
          </div>
        </div>

        {/* Portion split */}
        <div className="flex items-center justify-between">
          <label className="text-sm font-semibold">Log a single portion</label>
          <button onClick={() => setPartial((p) => !p)} role="switch" aria-checked={partial}
            className="w-11 h-6 rounded-full transition-colors relative shrink-0"
            style={{ background: partial ? "var(--primary)" : "var(--surface-highest)" }}>
            <span className="absolute top-0.5 w-5 h-5 rounded-full transition-transform"
              style={{ background: "#fff", left: 2, transform: partial ? "translateX(20px)" : "none" }} />
          </button>
        </div>

        {partial && (
          <div className="flex items-center gap-3">
            <span className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>Split into</span>
            <div className="flex items-center gap-1 ml-auto">
              <button onClick={() => setDivisor((d) => Math.max(1, d - 1))}
                className="w-7 h-7 rounded-[var(--r-sm)] flex items-center justify-center" style={{ background: "var(--surface-highest)" }}>
                <span className="material-symbols-rounded text-base">remove</span>
              </button>
              <span className="w-10 text-center text-sm font-semibold tabular">{divisor}</span>
              <button onClick={() => setDivisor((d) => Math.min(20, d + 1))}
                className="w-7 h-7 rounded-[var(--r-sm)] flex items-center justify-center" style={{ background: "var(--surface-highest)" }}>
                <span className="material-symbols-rounded text-base">add</span>
              </button>
            </div>
          </div>
        )}

        {/* Macro preview */}
        <div className="flex gap-4 text-sm tabular px-1 pt-2" style={{ borderTop: "1px solid var(--outline)" }}>
          <span style={{ color: "var(--metric-kcal)" }}>{Math.round(totalKcal / effDivisor)} kcal</span>
          <span style={{ color: "var(--metric-protein)" }}>{Math.round(totalProtein / effDivisor)}g protein</span>
        </div>

        <button onClick={() => mutation.mutate()} disabled={mutation.isPending || recipe.ingredients.length === 0}
          className="h-10 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-60"
          style={{ background: "var(--primary)", color: "#1E1F18" }}>
          {mutation.isPending ? "Logging…" : "Log meal"}
        </button>
      </div>
    </div>
  );
}
