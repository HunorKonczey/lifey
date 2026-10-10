"use client";

import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { Button, IconButton, NumberField, SegmentedControl, Switch } from "@/components/ds";
import { Modal } from "@/components/ds/overlay/Modal";
import { useFormat } from "@/lib/format/useFormat";
import { useFormat as useNumberFormat } from "@/lib/i18n/format";
import { foodApi, mealApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { logTimestampFor } from "@/lib/utils/logTime";
import {
  buildEntries, gramsFor, scaledMacros, type GramsOverrides,
} from "../logRecipePortion";
import { recipeFiberSugar } from "../fiberSugar";
import { defaultMealType } from "../mealTypeDefault";
import { MEAL_TYPE_ORDER } from "../mealTypeStyle";
import type { FoodResponse, MealEntryRequest, MealType, RecipeResponse } from "../types";
import { FiberSugarLine } from "./FiberSugarLine";

export interface LogRecipeModalProps {
  recipe: RecipeResponse;
  /** Carbs and fat of the preview come from these foods (the recipe API carries only kcal and protein). */
  foodsById: ReadonlyMap<number, FoodResponse>;
  initialMealType?: MealType;
  pending?: boolean;
  onConfirm: (result: { mealType: MealType; entries: MealEntryRequest[] }) => void;
  onClose: () => void;
}

/**
 * Log a whole recipe as a meal (W2.11): its ingredients become the meal's entries. Optionally split into
 * portions (the switch is on by default when the recipe has several servings, dividing every ingredient's
 * grams by the portion count); behind "Hozzávalók módosítása" each ingredient's per-portion grams can be
 * overridden with what was actually eaten (0 leaves it out) — hidden by default so the plain log-as-is flow
 * stays untouched. The preview shows kcal and the three macros of exactly what will be logged.
 */
export function LogRecipeModal({ recipe, foodsById, initialMealType, pending, onConfirm, onClose }: LogRecipeModalProps) {
  const t = useTranslations("nutrition.logRecipeDialog");
  const n = useTranslations("nutrition");
  const common = useTranslations("common");
  const fmt = useFormat();
  const nf = useNumberFormat();
  const [mealType, setMealType] = useState<MealType>(initialMealType ?? defaultMealType());
  const [partial, setPartial] = useState(recipe.servings > 1);
  const [divisor, setDivisor] = useState(Math.min(Math.max(recipe.servings, 1), 20));
  const [showIngredients, setShowIngredients] = useState(false);
  // User-typed per-ingredient amounts (keyed by ingredient index); the others show the divisor-derived default.
  const [overrides, setOverrides] = useState<GramsOverrides>({});

  const mealLabels: Record<MealType, string> = {
    BREAKFAST: n("breakfast"),
    LUNCH: n("lunch"),
    SNACK: n("snack"),
    DINNER: n("dinner"),
  };

  const effDivisor = partial ? divisor : 1;
  const macros = scaledMacros(recipe.ingredients, effDivisor, overrides, foodsById);
  const entries = buildEntries(recipe.ingredients, effDivisor, overrides);
  const fiberSugar = recipeFiberSugar(recipe.ingredients, foodsById, (ingredient, i) => gramsFor(ingredient, i, effDivisor, overrides));

  const resetOverride = (index: number) =>
    setOverrides((o) => {
      const next = { ...o };
      delete next[index];
      return next;
    });

  return (
    <Modal open onClose={onClose} width={480} aria-label={t("title")}>
      <div className="flex max-h-[85vh] flex-col gap-5 overflow-y-auto p-6">
        <div className="min-w-0">
          <h2 className="type-title-l">{t("title")}</h2>
          <p className="type-body-s truncate" style={{ color: "var(--text-3)" }}>
            {t("ingredientsSummary", { name: recipe.name, count: recipe.ingredients.length })}
          </p>
        </div>

        <div className="flex flex-col gap-2">
          <span className="type-label" style={{ color: "var(--text-3)", fontWeight: 700 }}>
            {t("meal")}
          </span>
          <SegmentedControl<MealType>
            aria-label={t("meal")}
            options={MEAL_TYPE_ORDER.map((m) => ({ value: m, label: mealLabels[m] }))}
            value={mealType}
            onChange={setMealType}
          />
        </div>

        <div className="flex items-center justify-between gap-3">
          <Switch checked={partial} onChange={setPartial} label={t("singlePortion")} />
          {partial && (
            <NumberField
              aria-label={t("splitInto")}
              size="dense"
              className="w-40"
              value={divisor}
              onChange={(v) => setDivisor(Math.min(20, Math.max(1, Math.round(v))))}
              min={1}
              max={20}
              maxDecimals={0}
              selectOnFocus
            />
          )}
        </div>
        {partial && (
          <p className="type-body-s -mt-3" style={{ color: "var(--text-3)" }}>
            {t("splitHint", { count: divisor })}
          </p>
        )}

        {recipe.ingredients.length > 0 && (
          <div className="flex flex-col gap-2">
            <button
              type="button"
              aria-expanded={showIngredients}
              onClick={() => setShowIngredients((s) => !s)}
              className="lifey-button type-body-s inline-flex items-center gap-1.5 self-start"
              style={{ fontWeight: 700, color: "var(--text-2)", borderRadius: "var(--r-control)" }}
            >
              <span className="material-symbols-rounded" style={{ fontSize: 18 }} aria-hidden>
                {showIngredients ? "expand_less" : "tune"}
              </span>
              {t("adjustIngredients")}
            </button>
            {showIngredients && (
              <>
                <p className="type-body-s" style={{ color: "var(--text-3)" }}>{t("amountsHint")}</p>
                {recipe.ingredients.map((ing, i) => (
                  <div
                    key={i}
                    className="flex items-center gap-2 px-3 py-2"
                    style={{ background: "var(--nested)", borderRadius: "var(--r-control)" }}
                    data-testid="log-ingredient"
                  >
                    <span className="type-body-s min-w-0 flex-1 truncate">{ing.foodName}</span>
                    {overrides[i] !== undefined && (
                      <IconButton icon="restart_alt" label={t("resetAmount")} onClick={() => resetOverride(i)} />
                    )}
                    <NumberField
                      aria-label={ing.foodName}
                      size="dense"
                      className="w-36"
                      unit="g"
                      value={gramsFor(ing, i, effDivisor, overrides)}
                      onChange={(v) => setOverrides((o) => ({ ...o, [i]: String(v) }))}
                      min={0}
                      step={5}
                      maxDecimals={2}
                      selectOnFocus
                    />
                  </div>
                ))}
              </>
            )}
          </div>
        )}

        <p
          className="type-body-s tabular pt-3"
          style={{ borderTop: "1px solid var(--hairline)", fontWeight: 700 }}
          data-testid="log-preview"
        >
          {t("preview", {
            kcal: fmt.integer(macros.calories),
            protein: nf.number(macros.protein, 0),
            carbs: nf.number(macros.carbs, 0),
            fat: nf.number(macros.fat, 0),
          })}
        </p>
        <FiberSugarLine totals={fiberSugar} testId="log-fiber-sugar" className="-mt-3" />

        <div className="flex flex-wrap gap-3">
          <Button variant="secondary" onClick={onClose} className="min-w-[140px] flex-1">
            {common("cancel")}
          </Button>
          <Button onClick={() => onConfirm({ mealType, entries })} disabled={pending || entries.length === 0} className="min-w-[140px] flex-1">
            {pending ? t("logging") : t("logMeal")}
          </Button>
        </div>
      </div>
    </Modal>
  );
}

/** The connected dialog: logs the recipe as a meal on `date` and closes. */
export function LogRecipeDialog({ recipe, date, onClose }: { recipe: RecipeResponse; date: Date; onClose: () => void }) {
  const t = useTranslations("nutrition.logRecipeDialog");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const { data: foods } = useQuery({ queryKey: queryKeys.foods.all(), queryFn: foodApi.list });
  const foodsById = new Map((foods ?? []).map((f) => [f.id, f]));

  const mutation = useMutation({
    mutationFn: ({ mealType, entries }: { mealType: MealType; entries: MealEntryRequest[] }) =>
      mealApi.create({ dateTime: logTimestampFor(date), mealType, name: recipe.name, entries }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.meals.all() });
      show(t("logged", { name: recipe.name }), "success");
      onClose();
    },
    onError: () => show(t("logFailed"), "error"),
  });

  return <LogRecipeModal recipe={recipe} foodsById={foodsById} pending={mutation.isPending} onConfirm={(r) => mutation.mutate(r)} onClose={onClose} />;
}
