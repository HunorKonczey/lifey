"use client";

import { useEffect, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { format } from "date-fns";
import { Button } from "@/components/ds";
import { NumberField } from "@/components/ds/field/NumberField";
import { SegmentedControl } from "@/components/ds/SegmentedControl";
import { settingsApi } from "@/features/settings/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useFormat } from "@/lib/format/useFormat";
import { useToast } from "@/lib/hooks/useToast";
import { logTimestampFor } from "@/lib/utils/logTime";
import { foodApi, mealApi } from "../../api";
import { remainingAfter, type Nutrients } from "../../budget";
import { parseMacroDraft, per100g, type ParsedMacroEntry } from "../../macroEntry";
import { MEAL_TYPE_ORDER } from "../../mealTypeStyle";
import { buildEntries } from "../../logRecipePortion";
import { foodPortion, recipePortion, type Macros } from "../../recipeMacros";
import type { SearchItem } from "../../foodSearch";
import type { FoodResponse, MealResponse, MealType } from "../../types";
import { useAddFoodContext } from "./AddFoodModal";

const MEAL_KEY = { BREAKFAST: "breakfast", LUNCH: "lunch", SNACK: "snack", DINNER: "dinner" } as const;

export type AddRequest =
  | {
      kind: "item";
      item: SearchItem;
      /** Grams for a food, servings for a recipe. */
      quantity: number;
      mealType: MealType;
    }
  | { kind: "macros"; entry: ParsedMacroEntry; mealType: MealType };

export interface FoodPreviewPaneViewProps {
  foodsById: ReadonlyMap<number, FoodResponse>;
  initialMealType: MealType;
  /** The day's total as stored, and its goals — for "Utána marad". */
  consumed: Nutrients;
  goals: { dailyCalorieGoal: number | null; dailyProteinGoal: number | null };
  pending?: boolean;
  /** Resolves once it is saved (the dialog then clears itself for the next one) and rejects when it failed. */
  onSubmit: (req: AddRequest) => Promise<unknown> | void;
  /** "Done" — the dialog stays open after an add, so this is the way out. */
  onDone: () => void;
}

function defaultQuantity(item: SearchItem | null, lastGrams: number | undefined): number {
  if (!item) return 100;
  return item.kind === "recipe" ? 1 : (lastGrams ?? 100);
}

function macrosOf(item: SearchItem | null, qty: number, foodsById: ReadonlyMap<number, FoodResponse>): Macros {
  if (!item || qty <= 0) return { calories: 0, protein: 0, carbs: 0, fat: 0 };
  return item.kind === "food" ? foodPortion(item.food, qty) : recipePortion(item.recipe, foodsById, qty);
}

/**
 * The add-food dialog's right pane (W2.6, client-006): the highlighted row's
 * name and source, the quantity (grams — or servings for a recipe) with "100 g"
 * and last-used chips, the meal type (defaulting by the clock), a four-tile
 * macro preview, "Utána marad 749 kcal · fehérje még 37 g" and Mégse / a submit
 * that names the meal it goes to. Enter in the search field or in the quantity
 * adds; Tab from the search field lands here. An add does not close the dialog
 * — the search clears for the next food, "Kész" closes it. In the "Enter macros"
 * mode the preview shows the typed totals instead. Presentational — the data and
 * the save are `FoodPreviewPane`.
 */
export function FoodPreviewPaneView({ foodsById, initialMealType, consumed, goals, pending, onSubmit, onDone }: FoodPreviewPaneViewProps) {
  const t = useTranslations("nutrition.addFoodModal");
  const n = useTranslations("nutrition");
  const d = useTranslations("dashboard");
  const fmt = useFormat();
  const { active, usage, registerQuantity, setCommit, mode, macroDraft, reset } = useAddFoodContext();

  const lastGrams = active ? usage.get(active.key)?.lastGrams : undefined;
  const [mealType, setMealType] = useState<MealType>(initialMealType);
  const [qty, setQty] = useState(() => defaultQuantity(active, lastGrams));
  // A new highlighted row starts from its own default quantity (adjusted during render, not in an effect).
  const [forKey, setForKey] = useState(active?.key ?? null);
  if ((active?.key ?? null) !== forKey) {
    setForKey(active?.key ?? null);
    setQty(defaultQuantity(active, lastGrams));
  }

  const inMacros = mode === "macros";
  const entry = inMacros ? parseMacroDraft(macroDraft) : null;
  const isRecipe = !inMacros && active?.kind === "recipe";
  const macros = inMacros
    ? (entry?.totals ?? { calories: 0, protein: 0, carbs: 0, fat: 0 })
    : macrosOf(active, qty, foodsById);
  const left = remainingAfter(consumed, goals, { calories: macros.calories, protein: macros.protein });
  const canSubmit = !pending && (inMacros ? !!entry : !!active && qty > 0);

  const submit = () => {
    if (!canSubmit) return;
    const req: AddRequest | null = inMacros
      ? entry && { kind: "macros", entry, mealType }
      : active && { kind: "item", item: active, quantity: qty, mealType };
    if (!req) return;
    Promise.resolve(onSubmit(req)).then(
      () => {
        // Stay open for the next one: a fresh search, and a fresh default quantity even when the same row is first again.
        reset();
        setForKey("");
      },
      () => {}, // already reported by the caller; the typed values stay
    );
  };
  // Enter in the search field adds with whatever the quantity currently is.
  useEffect(() => {
    setCommit(submit);
    return () => setCommit(null);
  });

  if (!inMacros && !active) {
    return (
      <div className="flex h-full min-h-[300px] items-center justify-center text-center">
        <p className="type-body-s" style={{ color: "var(--text-3)", maxWidth: 220 }}>
          {t("pickSomething")}
        </p>
      </div>
    );
  }

  const chips = isRecipe ? [0.5, 1, 2] : [100, ...(lastGrams && Math.round(lastGrams) !== 100 ? [Math.round(lastGrams)] : [])];
  const title = inMacros ? entry?.name || macroDraft.name.trim() || t("customEntry") : active!.name;
  const source = inMacros
    ? t("previewSourceMacros", { g: fmt.integer(entry?.grams ?? 100) })
    : active!.kind === "recipe"
      ? t("previewSourceRecipe", { n: active!.recipe.servings })
      : t("previewSourceFood", { kcal: fmt.integer(active!.food.caloriesPer100g) });

  const tiles: { key: string; label: string; value: string; color: string; hero?: boolean }[] = [
    { key: "kcal", label: t("previewCalories"), value: fmt.integer(macros.calories), color: "var(--m-kcal)", hero: true },
    { key: "protein", label: d("protein"), value: fmt.grams(macros.protein), color: "var(--m-protein)" },
    { key: "carbs", label: d("carbs"), value: fmt.grams(macros.carbs), color: "var(--m-carbs)" },
    { key: "fat", label: d("fat"), value: fmt.grams(macros.fat), color: "var(--m-fat)" },
  ];

  const goalKcal = goals.dailyCalorieGoal;
  const eatenFrac = goalKcal ? Math.min(1, consumed.calories / goalKcal) : 0;
  const addFrac = goalKcal ? Math.min(1 - eatenFrac, macros.calories / goalKcal) : 0;

  return (
    <form
      className="flex h-full flex-col gap-5"
      onSubmit={(e) => {
        e.preventDefault();
        submit();
      }}
    >
      <div className="pr-8">
        <h3 data-testid="preview-title" style={{ fontSize: 22, fontWeight: 800, letterSpacing: "-0.02em", overflowWrap: "anywhere" }}>
          {title}
        </h3>
        <p className="type-body-s" style={{ color: "var(--text-3)" }}>
          {source}
        </p>
      </div>

      {!inMacros && (
      <div>
        <div className="flex flex-wrap items-end gap-3">
          <NumberField
            label={t("quantity")}
            value={qty}
            onChange={setQty}
            unit={isRecipe ? t("servingsUnit") : "g"}
            step={isRecipe ? 0.5 : 10}
            min={isRecipe ? 0.25 : 1}
            max={isRecipe ? 50 : 5000}
            maxDecimals={isRecipe ? 2 : 1}
            inputRef={registerQuantity}
            liveUpdate
            selectOnFocus
            onEnter={submit}
            className="w-44"
          />
          <div className="flex gap-2 pb-1.5" role="group" aria-label={t("quantityChips")}>
            {chips.map((c) => (
              <button
                key={c}
                type="button"
                onClick={() => setQty(c)}
                aria-pressed={qty === c}
                className="lifey-button type-body-s tabular"
                style={{
                  height: 32,
                  padding: "0 12px",
                  borderRadius: "var(--r-pill)",
                  fontWeight: 700,
                  background: qty === c ? "var(--primary-tint)" : "var(--nested)",
                  color: qty === c ? "var(--on-primary-tint)" : "var(--text-2)",
                }}
              >
                {isRecipe ? t("servingsChip", { n: c }) : `${c} g`}
              </button>
            ))}
          </div>
        </div>
      </div>
      )}

      <SegmentedControl<MealType>
        aria-label={t("meal")}
        value={mealType}
        onChange={setMealType}
        options={MEAL_TYPE_ORDER.map((type) => ({ value: type, label: n(MEAL_KEY[type]) }))}
      />

      <div className="grid grid-cols-4 gap-2" data-testid="preview-macros">
        {tiles.map((tile) => (
          <div
            key={tile.key}
            data-tile={tile.key}
            className="flex flex-col gap-0.5 px-3 py-2.5"
            style={{
              borderRadius: "var(--r-control)",
              background: tile.hero ? `color-mix(in srgb, ${tile.color} var(--chip-tint), transparent)` : "var(--nested)",
            }}
          >
            <span className="type-label" style={{ color: tile.color }}>
              {tile.label}
            </span>
            <span className="tabular" style={{ fontSize: 20, fontWeight: 800 }}>
              {tile.value}
            </span>
          </div>
        ))}
      </div>

      {inMacros && !entry && (
        <p className="type-body-s" style={{ color: "var(--text-3)" }}>
          {t("macroNeedsCalories")}
        </p>
      )}

      {(left.calories != null || left.protein != null) && (
        <div className="flex flex-col gap-2" data-testid="preview-remaining">
          <p className="type-body-s" style={{ color: "var(--text-2)" }}>
            {left.calories != null &&
              (left.calories >= 0
                ? t.rich("afterLeft", { kcal: fmt.integer(left.calories), b: (c) => <b style={{ color: "var(--text)" }}>{c}</b> })
                : t.rich("afterOver", { kcal: fmt.integer(-left.calories), b: (c) => <b style={{ color: "var(--m-kcal)" }}>{c}</b> }))}
            {left.calories != null && left.protein != null && " · "}
            {left.protein != null &&
              (left.protein > 0 ? t("proteinToGo", { g: fmt.integer(left.protein) }) : t("proteinReached"))}
          </p>
          {goalKcal != null && (
            <div className="flex overflow-hidden" style={{ height: 8, borderRadius: 4, background: "var(--control)" }} aria-hidden>
              <div style={{ width: `${eatenFrac * 100}%`, background: "color-mix(in srgb, var(--m-kcal) 55%, transparent)" }} />
              <div style={{ width: `${addFrac * 100}%`, background: "var(--m-kcal)" }} />
            </div>
          )}
        </div>
      )}

      <div className="mt-auto flex items-center justify-end gap-3 pt-2">
        <Button type="button" variant="ghost" onClick={onDone}>
          {t("done")}
        </Button>
        <Button type="submit" disabled={!canSubmit}>
          {t("submitTo", { meal: mealType })}
        </Button>
      </div>
    </form>
  );
}

/** The connected pane: foods (for recipe macros), the day's meals and goals, and the save. */
export function FoodPreviewPane({
  date,
  initialMealType,
  onClose,
}: {
  date: Date;
  initialMealType: MealType;
  onClose: () => void;
}) {
  const n = useTranslations("nutrition");
  const t = useTranslations("nutrition.addFoodModal");
  const queryClient = useQueryClient();
  const { show } = useToast();

  const { data: foods } = useQuery({ queryKey: queryKeys.foods.all(), queryFn: foodApi.list });
  const { data: meals } = useQuery({ queryKey: queryKeys.meals.all(), queryFn: mealApi.list });
  const { data: settings } = useQuery({ queryKey: queryKeys.settings.all(), queryFn: settingsApi.get, staleTime: 5 * 60_000 });

  const foodsById = new Map((foods ?? []).map((f) => [f.id, f] as const));
  const dateStr = format(date, "yyyy-MM-dd");
  const dayMeals = (meals ?? []).filter((m) => format(new Date(m.dateTime), "yyyy-MM-dd") === dateStr);
  const consumed = dayMeals.reduce(
    (acc, m) => {
      for (const e of m.entries) {
        acc.calories += e.calories;
        acc.protein += e.protein;
      }
      return acc;
    },
    { calories: 0, protein: 0 },
  );

  // A food goes into the day's latest plain meal of that type, else starts one; a recipe meal
  // (it has a name) is never extended with loose foods.
  const addFoodEntry = async (foodId: number, grams: number, mealType: MealType) => {
    const target = dayMeals
      .filter((m): m is MealResponse => m.mealType === mealType && m.name == null)
      .sort((a, b) => new Date(b.dateTime).getTime() - new Date(a.dateTime).getTime())[0];
    const entry = { foodId, quantityInGrams: grams };
    if (target) {
      await mealApi.update(target.id, {
        dateTime: target.dateTime,
        mealType,
        name: null,
        entries: [...target.entries.map((e) => ({ foodId: e.foodId, quantityInGrams: e.quantityInGrams })), entry],
      });
    } else {
      await mealApi.create({ dateTime: logTimestampFor(date), mealType, name: null, entries: [entry] });
    }
  };

  const add = useMutation({
    mutationFn: async (req: AddRequest): Promise<MealType> => {
      const { mealType } = req;
      if (req.kind === "macros") {
        // Typed totals become a hidden one-off food (per 100 g back-calculated), so the meal keeps its normal shape.
        const p = per100g(req.entry.totals, req.entry.grams);
        const food = await foodApi.create({
          name: req.entry.name || t("customEntry"),
          caloriesPer100g: p.calories,
          proteinPer100g: p.protein,
          carbsPer100g: p.carbs,
          fatPer100g: p.fat,
          hidden: true,
        });
        await addFoodEntry(food.id, req.entry.grams, mealType);
      } else if (req.item.kind === "recipe") {
        // A logged recipe is its own meal, named after it (`LogRecipeDialog` does the same).
        const servings = Math.max(req.item.recipe.servings, 1);
        await mealApi.create({
          dateTime: logTimestampFor(date),
          mealType,
          name: req.item.recipe.name,
          entries: buildEntries(req.item.recipe.ingredients, servings / req.quantity, {}),
        });
      } else {
        await addFoodEntry(req.item.food.id, req.quantity, mealType);
      }
      return mealType;
    },
    onSuccess: (mealType) => {
      show(t("added", { meal: n(MEAL_KEY[mealType]) }), "success");
      // Waited for: the dialog stays open, and the next add must see this meal (and the new "left") to extend it, not start a second one.
      return queryClient.invalidateQueries({ queryKey: queryKeys.meals.all() });
    },
    onError: () => show(t("addFailed"), "error"),
  });

  return (
    <FoodPreviewPaneView
      foodsById={foodsById}
      initialMealType={initialMealType}
      consumed={consumed}
      goals={{ dailyCalorieGoal: settings?.dailyCalorieGoal ?? null, dailyProteinGoal: settings?.dailyProteinGoal ?? null }}
      pending={add.isPending}
      onSubmit={(req) => add.mutateAsync(req)}
      onDone={onClose}
    />
  );
}
