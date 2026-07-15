"use client";

import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { mealApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { logTimestampFor } from "@/lib/utils/logTime";
import {
  buildEntries, defaultGrams, scaledTotals, type GramsOverrides,
} from "../logRecipePortion";
import type { RecipeResponse, MealType } from "../types";

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
 * Behind the "Adjust ingredients" button, each ingredient's per-portion grams
 * can be overridden with what was actually eaten (0 leaves it out) — hidden
 * by default so the plain log-as-is flow stays untouched.
 */
export function LogRecipeDialog({
  recipe, date, onClose,
}: {
  recipe: RecipeResponse;
  date: Date;
  onClose: () => void;
}) {
  const t = useTranslations("nutrition.logRecipeDialog");
  const n = useTranslations("nutrition");
  const common = useTranslations("common");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [mealType, setMealType] = useState<MealType>(defaultMealType());

  const MEAL_TYPES: { value: MealType; label: string }[] = [
    { value: "BREAKFAST", label: n("breakfast") },
    { value: "LUNCH", label: n("lunch") },
    { value: "DINNER", label: n("dinner") },
    { value: "SNACK", label: n("snack") },
  ];
  const [partial, setPartial] = useState(recipe.servings > 1);
  const [divisor, setDivisor] = useState(Math.min(Math.max(recipe.servings, 1), 20));
  const [showIngredients, setShowIngredients] = useState(false);
  // User-typed per-ingredient amounts (raw text, keyed by ingredient index);
  // non-overridden ingredients display the divisor-derived default.
  const [overrides, setOverrides] = useState<GramsOverrides>({});

  const effDivisor = partial ? divisor : 1;
  const totals = scaledTotals(recipe.ingredients, effDivisor, overrides);
  const entries = buildEntries(recipe.ingredients, effDivisor, overrides);

  const resetOverride = (index: number) =>
    setOverrides((o) => {
      const next = { ...o };
      delete next[index];
      return next;
    });

  const mutation = useMutation({
    mutationFn: () => {
      return mealApi.create({
        dateTime: logTimestampFor(date),
        mealType,
        name: recipe.name,
        entries,
      });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.meals.all() });
      show(t("logged", { name: recipe.name }), "success");
      onClose();
    },
    onError: () => show(t("logFailed"), "error"),
  });

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center p-4"
      style={{ background: "rgba(0,0,0,.5)" }} onClick={onClose}>
      <div className="w-full max-w-md rounded-[var(--r-lg)] p-5 flex flex-col gap-4 max-h-[90vh] overflow-y-auto"
        style={{ background: "var(--surface)" }} onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between">
          <div>
            <h3 className="font-bold text-base">{t("title")}</h3>
            <p className="text-xs" style={{ color: "var(--muted)" }}>
              {t("ingredientsSummary", { name: recipe.name, count: recipe.ingredients.length })}
            </p>
          </div>
          <button onClick={onClose} aria-label={common("close")} className="p-1 rounded-[var(--r-sm)]">
            <span className="material-symbols-rounded">close</span>
          </button>
        </div>

        {/* Meal type */}
        <div className="flex flex-col gap-1.5">
          <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>{t("meal")}</label>
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
          <label className="text-sm font-semibold">{t("singlePortion")}</label>
          <button onClick={() => setPartial((p) => !p)} role="switch" aria-checked={partial}
            className="w-11 h-6 rounded-full transition-colors relative shrink-0"
            style={{ background: partial ? "var(--primary)" : "var(--surface-highest)" }}>
            <span className="absolute top-0.5 w-5 h-5 rounded-full transition-transform"
              style={{ background: "#fff", left: 2, transform: partial ? "translateX(20px)" : "none" }} />
          </button>
        </div>

        {partial && (
          <div className="flex items-center gap-3">
            <span className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>{t("splitInto")}</span>
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

        {/* Adjustable per-portion ingredient amounts, opt-in behind a button */}
        {recipe.ingredients.length > 0 && (
          <div className="flex flex-col gap-2">
            <button onClick={() => setShowIngredients((s) => !s)}
              className="flex items-center gap-1 self-start text-xs font-semibold"
              style={{ color: "var(--on-surface-variant)" }}>
              <span className="material-symbols-rounded text-base">
                {showIngredients ? "expand_less" : "tune"}
              </span>
              {t("adjustIngredients")}
            </button>
            {showIngredients && (
              <>
                <p className="text-xs" style={{ color: "var(--muted)" }}>{t("amountsHint")}</p>
                {recipe.ingredients.map((ing, i) => {
                  const overridden = overrides[i] !== undefined;
                  return (
                    <div key={i} className="flex items-center gap-2 px-3 py-2 rounded-[var(--r-md)]"
                      style={{ background: "var(--surface-container)" }}>
                      <span className="flex-1 min-w-0 text-sm truncate">{ing.foodName}</span>
                      {overridden && (
                        <button onClick={() => resetOverride(i)} title={t("resetAmount")}
                          aria-label={t("resetAmount")} style={{ color: "var(--muted)" }}>
                          <span className="material-symbols-rounded text-lg">restart_alt</span>
                        </button>
                      )}
                      <input type="text" inputMode="decimal"
                        value={overrides[i] ?? String(defaultGrams(ing, effDivisor))}
                        onChange={(e) => setOverrides((o) => ({ ...o, [i]: e.target.value }))}
                        className="w-20 px-2 h-8 rounded-[var(--r-sm)] outline-none text-sm text-right tabular"
                        style={{ background: "var(--surface)", border: "1px solid var(--outline)" }} />
                      <span className="text-xs" style={{ color: "var(--muted)" }}>g</span>
                    </div>
                  );
                })}
              </>
            )}
          </div>
        )}

        {/* Macro preview */}
        <div className="flex gap-4 text-sm tabular px-1 pt-2" style={{ borderTop: "1px solid var(--outline)" }}>
          <span style={{ color: "var(--metric-kcal)" }}>{Math.round(totals.calories)} kcal</span>
          <span style={{ color: "var(--metric-protein)" }}>{Math.round(totals.protein)}g protein</span>
        </div>

        <button onClick={() => mutation.mutate()} disabled={mutation.isPending || entries.length === 0}
          className="h-10 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-60"
          style={{ background: "var(--primary)", color: "#1E1F18" }}>
          {mutation.isPending ? t("logging") : t("logMeal")}
        </button>
      </div>
    </div>
  );
}
