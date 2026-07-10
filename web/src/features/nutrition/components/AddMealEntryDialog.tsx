"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { format } from "date-fns";
import { foodApi, mealApi } from "../api";
import { settingsApi } from "@/features/settings/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { logTimestampFor } from "@/lib/utils/logTime";
import { normalizeForSearch } from "@/lib/utils/search";
import { computeFoodUsage, rankFoodsByUsage, recentFoodsByUsage, type FoodUsage } from "../usage";
import { isOver, remainingOf, type BudgetMetric } from "../budget";
import type { MealType, FoodResponse, MealResponse } from "../types";

interface AddMealEntryDialogProps {
  mealType: MealType;
  date: Date;
  onClose: () => void;
  /** When set, the dialog edits this existing meal's items instead of creating a new meal. */
  meal?: MealResponse;
}

type Mode = "search" | "macros";

interface DraftItem {
  foodId: number;
  foodName: string;
  quantityInGrams: number;
  caloriesPer100g: number;
  proteinPer100g: number;
  carbsPer100g: number;
  fatPer100g: number;
}

function draftItemsFromMeal(meal: MealResponse): DraftItem[] {
  return meal.entries.map((e) => ({
    foodId: e.foodId,
    foodName: e.foodName,
    quantityInGrams: e.quantityInGrams,
    caloriesPer100g: e.quantityInGrams > 0 ? ((e.calories ?? 0) * 100) / e.quantityInGrams : 0,
    proteinPer100g: e.quantityInGrams > 0 ? ((e.protein ?? 0) * 100) / e.quantityInGrams : 0,
    carbsPer100g: e.quantityInGrams > 0 ? ((e.carbs ?? 0) * 100) / e.quantityInGrams : 0,
    fatPer100g: e.quantityInGrams > 0 ? ((e.fat ?? 0) * 100) / e.quantityInGrams : 0,
  }));
}

export function AddMealEntryDialog({ mealType, date, onClose, meal }: AddMealEntryDialogProps) {
  const t = useTranslations("nutrition.addMealDialog");
  const n = useTranslations("nutrition");
  const common = useTranslations("common");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const isEditing = meal != null;
  const [mode, setMode] = useState<Mode>("search");
  const [items, setItems] = useState<DraftItem[]>(() => (meal ? draftItemsFromMeal(meal) : []));

  const { data: recentMeals } = useQuery({ queryKey: queryKeys.meals.all(), queryFn: mealApi.list });
  const usage = computeFoodUsage(recentMeals ?? []);

  const { data: settings } = useQuery({
    queryKey: queryKeys.settings.all(),
    queryFn: settingsApi.get,
    staleTime: 5 * 60_000,
  });

  // "What's left" outcome preview (W3): today's already-saved consumption
  // (excluding this meal's own pre-edit entries, since `items` supersedes
  // them) plus whatever's staged in this dialog so far — only meaningful
  // when logging for today and a calorie goal is set.
  const dateStr = format(date, "yyyy-MM-dd");
  const isTodayDate = dateStr === format(new Date(), "yyyy-MM-dd");
  const otherTodayMeals = (recentMeals ?? []).filter(
    (m) => format(new Date(m.dateTime), "yyyy-MM-dd") === dateStr && m.id !== meal?.id,
  );
  const stagedKcal = items.reduce((s, i) => s + (i.caloriesPer100g * i.quantityInGrams) / 100, 0);
  const currentTodayKcal =
    otherTodayMeals.reduce((s, m) => s + m.entries.reduce((es, e) => es + e.calories, 0), 0) + stagedKcal;
  const budgetContext =
    isTodayDate && settings?.dailyCalorieGoal != null
      ? { calorieGoal: settings.dailyCalorieGoal, currentTodayKcal }
      : null;

  const addItem = (item: DraftItem) => setItems((prev) => [...prev, item]);
  const removeItem = (idx: number) => setItems((prev) => prev.filter((_, i) => i !== idx));
  const updateGrams = (idx: number, grams: number) =>
    setItems((prev) => prev.map((it, i) => (i === idx ? { ...it, quantityInGrams: grams } : it)));

  const totalKcal = items.reduce((s, i) => s + (i.caloriesPer100g * i.quantityInGrams) / 100, 0);
  const totalProtein = items.reduce((s, i) => s + (i.proteinPer100g * i.quantityInGrams) / 100, 0);
  const totalCarbs = items.reduce((s, i) => s + (i.carbsPer100g * i.quantityInGrams) / 100, 0);
  const totalFat = items.reduce((s, i) => s + (i.fatPer100g * i.quantityInGrams) / 100, 0);

  const saveMutation = useMutation({
    mutationFn: () => {
      const entries = items.map((i) => ({ foodId: i.foodId, quantityInGrams: i.quantityInGrams }));
      return meal
        ? mealApi.update(meal.id, { dateTime: meal.dateTime, mealType: meal.mealType, name: meal.name, entries })
        : mealApi.create({ dateTime: logTimestampFor(date), mealType, name: null, entries });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.meals.all() });
      show(isEditing ? t("mealUpdated") : t("mealSaved"), "success");
      onClose();
    },
    onError: () => show(isEditing ? t("updateFailed") : t("saveFailed"), "error"),
  });

  const mealTypeLabels: Record<MealType, string> = {
    BREAKFAST: n("breakfast"), LUNCH: n("lunch"), DINNER: n("dinner"), SNACK: n("snack"),
  };

  return (
    <div
      className="fixed inset-0 z-40 flex items-center justify-center p-4"
      style={{ background: "rgba(0,0,0,.5)" }}
      onClick={onClose}
    >
      <div
        className="w-full max-w-md rounded-[var(--r-lg)] p-5 flex flex-col gap-4 max-h-[90vh] overflow-y-auto"
        style={{ background: "var(--surface)" }}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between">
          <h3 className="font-bold text-base">
            {isEditing ? t("editTitle", { meal: mealTypeLabels[mealType] }) : t("addTitle", { meal: mealTypeLabels[mealType] })}
          </h3>
          <button onClick={onClose} aria-label={common("close")}
            className="p-1 rounded-[var(--r-sm)] transition-colors hover:bg-surface-container">
            <span className="material-symbols-rounded">close</span>
          </button>
        </div>

        {/* Mode tabs */}
        <div className="flex gap-1 p-1 rounded-[var(--r-pill)]" style={{ background: "var(--surface-highest)" }}>
          {(["search", "macros"] as Mode[]).map((m) => (
            <button key={m} onClick={() => setMode(m)}
              className="flex-1 py-1 rounded-[var(--r-pill)] text-xs font-semibold transition-colors"
              style={{
                background: mode === m ? "var(--primary)" : "transparent",
                color: mode === m ? "#1E1F18" : "var(--on-surface-variant)",
              }}>
              {m === "search" ? t("searchFood") : t("enterMacros")}
            </button>
          ))}
        </div>

        {mode === "search" ? (
          <SearchMode onAdd={addItem} usage={usage} budgetContext={budgetContext} />
        ) : (
          <MacrosMode onAdd={addItem} />
        )}

        {/* Items added so far */}
        {items.length > 0 && (
          <div className="flex flex-col gap-2 pt-2" style={{ borderTop: "1px solid var(--outline)" }}>
            <p className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>
              {t("items", { count: items.length })}
            </p>
            {items.map((it, idx) => (
              <div key={idx} className="flex items-center gap-2 px-3 py-2 rounded-[var(--r-md)]"
                style={{ background: "var(--surface-container)" }}>
                <span className="flex-1 min-w-0 text-sm font-semibold truncate">{it.foodName}</span>
                <input type="number" min={1} value={it.quantityInGrams}
                  onChange={(e) => updateGrams(idx, Math.max(1, Number(e.target.value)))}
                  className="w-16 px-2 h-8 rounded-[var(--r-sm)] outline-none text-sm tabular"
                  style={{ background: "var(--surface)", border: "1px solid var(--outline)" }} />
                <span className="text-xs" style={{ color: "var(--muted)" }}>g</span>
                <button onClick={() => removeItem(idx)} style={{ color: "var(--muted)" }} aria-label={t("removeItemAria")}>
                  <span className="material-symbols-rounded text-lg">close</span>
                </button>
              </div>
            ))}

            <div className="flex flex-wrap gap-x-4 gap-y-1 text-sm tabular px-1">
              <span style={{ color: "var(--metric-kcal)" }}>{Math.round(totalKcal)} kcal</span>
              <span style={{ color: "var(--metric-protein)" }}>{Math.round(totalProtein)}g P</span>
              <span style={{ color: "var(--metric-carbs)" }}>{Math.round(totalCarbs)}g C</span>
              <span style={{ color: "var(--metric-fat)" }}>{Math.round(totalFat)}g F</span>
            </div>
          </div>
        )}

        <button onClick={() => saveMutation.mutate()} disabled={items.length === 0 || saveMutation.isPending}
          className="h-10 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-50"
          style={{ background: "var(--primary)", color: "#1E1F18" }}>
          {saveMutation.isPending
            ? common("saving")
            : isEditing
              ? t("saveChanges")
              : items.length > 0
                ? t("saveMealCount", { count: items.length })
                : t("saveMeal")}
        </button>
      </div>
    </div>
  );
}

function SearchMode({
  onAdd,
  usage,
  budgetContext,
}: {
  onAdd: (item: DraftItem) => void;
  usage: Map<number, FoodUsage>;
  /** Today's calorie goal + consumption so far (already-saved meals plus
   * whatever's staged in this dialog), so the quantity preview can show
   * "→ 420 kcal remaining" once a food + quantity are picked. Null when
   * logging for a non-today date or no calorie goal is set. */
  budgetContext: { calorieGoal: number; currentTodayKcal: number } | null;
}) {
  const t = useTranslations("nutrition.addMealDialog");
  const nf = useTranslations("nutrition.foodsView");
  const d = useTranslations("dashboard");
  const [search, setSearch] = useState("");
  const [picked, setPicked] = useState<FoodResponse | null>(null);
  const [gramsStr, setGramsStr] = useState("");
  const grams = gramsStr.trim() ? Math.max(1, Number(gramsStr)) : 0;

  const { data: foods } = useQuery({ queryKey: queryKeys.foods.all(), queryFn: foodApi.list });

  const nonHidden = (foods ?? []).filter((f) => !f.hidden);
  // Empty search with usage history: lead with a dedicated "Recent" section
  // (last-used quantity shown) instead of an arbitrary catalog slice. Empty
  // search with no history yet, or a non-empty query, falls back to the
  // usage-ranked (or plain, if no history) catalog — unchanged browsing
  // behavior for new users.
  const recents = search ? [] : recentFoodsByUsage(nonHidden, usage);
  const showingRecents = recents.length > 0;
  const filtered = search
    ? nonHidden.filter((f) => normalizeForSearch(f.name).includes(normalizeForSearch(search)))
    : nonHidden;
  const matches = (showingRecents ? [] : rankFoodsByUsage(filtered, usage)).slice(0, 8);

  const previewKcal = picked ? Math.round((picked.caloriesPer100g * grams) / 100) : 0;
  const previewProtein = picked ? Math.round((picked.proteinPer100g * grams) / 100) : 0;

  const pick = (f: FoodResponse) => {
    setPicked(f);
    const lastGrams = usage.get(f.id)?.lastGrams;
    setGramsStr(lastGrams ? String(Math.round(lastGrams)) : "");
  };

  const addAndReset = () => {
    if (!picked || grams <= 0) return;
    onAdd({
      foodId: picked.id,
      foodName: picked.name,
      quantityInGrams: grams,
      caloriesPer100g: picked.caloriesPer100g,
      proteinPer100g: picked.proteinPer100g,
      carbsPer100g: picked.carbsPer100g ?? 0,
      fatPer100g: picked.fatPer100g ?? 0,
    });
    setPicked(null);
    setSearch("");
    setGramsStr("");
  };

  if (!picked) {
    return (
      <>
        <div className="flex items-center gap-2 px-3 h-10 rounded-[var(--r-input)]"
          style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}
          data-ring-frame>
          <span className="material-symbols-rounded text-base" style={{ color: "var(--muted)" }}>search</span>
          <input autoFocus value={search} onChange={(e) => setSearch(e.target.value)}
            placeholder={nf("searchPlaceholder")} className="flex-1 min-w-0 bg-transparent outline-none text-sm" />
        </div>
        <div className="flex flex-col gap-1 max-h-64 overflow-y-auto">
          {showingRecents && (
            <p className="text-xs font-semibold px-3 pt-1 pb-0.5" style={{ color: "var(--on-surface-variant)" }}>
              {t("recent")}
            </p>
          )}
          {(showingRecents ? recents : matches).map((f) => (
            <button key={f.id} onClick={() => pick(f)}
              className="flex items-center justify-between px-3 py-2 rounded-[var(--r-md)] text-left transition-colors hover:bg-surface-container">
              <span className="text-sm font-semibold">{f.name}</span>
              {showingRecents ? (
                <span className="text-xs tabular" style={{ color: "var(--muted)" }}>
                  {t("lastGramsHint", { grams: Math.round(usage.get(f.id)!.lastGrams) })}
                </span>
              ) : (
                <span className="flex gap-2 text-xs tabular">
                  <span style={{ color: "var(--metric-kcal)" }}>{Math.round(f.caloriesPer100g)} kcal</span>
                  <span style={{ color: "var(--metric-protein)" }}>{Math.round(f.proteinPer100g)}g P</span>
                </span>
              )}
            </button>
          ))}
          {search && matches.length === 0 && (
            <p className="text-sm text-center py-4" style={{ color: "var(--muted)" }}>{t("noMatches")}</p>
          )}
        </div>
      </>
    );
  }

  return (
    <>
      <div className="flex items-center justify-between px-3 py-2 rounded-[var(--r-md)]"
        style={{ background: "var(--surface-container)" }}>
        <span className="text-sm font-semibold">{picked.name}</span>
        <button onClick={() => setPicked(null)} className="text-xs" style={{ color: "var(--primary)" }}>
          {t("change")}
        </button>
      </div>

      <div className="flex flex-col gap-1">
        <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>{t("quantityG")}</label>
        <input type="number" value={gramsStr} min={1} autoFocus placeholder="100"
          onChange={(e) => setGramsStr(e.target.value)}
          onFocus={(e) => e.target.select()}
          className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm tabular"
          style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
      </div>

      <div className="flex gap-4 text-sm tabular">
        <span style={{ color: "var(--metric-kcal)" }}>{previewKcal} kcal</span>
        <span style={{ color: "var(--metric-protein)" }}>{previewProtein}g protein</span>
      </div>

      {budgetContext && grams > 0 && (() => {
        const metric: BudgetMetric = {
          consumed: budgetContext.currentTodayKcal + previewKcal,
          goal: budgetContext.calorieGoal,
        };
        const remaining = remainingOf(metric)!;
        return (
          <p
            className="text-xs tabular"
            style={{ color: isOver(metric) ? "var(--goal-negative)" : "var(--on-surface-variant)" }}
          >
            {"→ "}
            {isOver(metric)
              ? d("over", { diff: Math.abs(Math.round(remaining)), unit: "kcal" })
              : d("remaining", { diff: Math.round(remaining), unit: "kcal" })}
          </p>
        );
      })()}

      <button onClick={addAndReset} disabled={grams <= 0}
        className="h-10 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-50"
        style={{ background: "var(--primary)", color: "#1E1F18" }}>
        {t("addItem")}
      </button>
    </>
  );
}

function MacrosMode({ onAdd }: { onAdd: (item: DraftItem) => void }) {
  const t = useTranslations("nutrition.addMealDialog");
  const { show } = useToast();
  const [name, setName] = useState("");
  const [gramsStr, setGramsStr] = useState("");
  const [kcal, setKcal] = useState("");
  const [protein, setProtein] = useState("");
  const [carbs, setCarbs] = useState("");
  const [fat, setFat] = useState("");

  const createFoodMutation = useMutation({
    mutationFn: async () => {
      const grams = gramsStr.trim() ? Math.max(1, Number(gramsStr)) : 100;
      const kcalVal = Number(kcal);
      const proteinVal = Number(protein);
      const carbsVal = carbs.trim() ? Number(carbs) : 0;
      const fatVal = fat.trim() ? Number(fat) : 0;

      // Back-calculate per-100g so that stored × grams / 100 = entered totals
      const factor = 100 / grams;
      const food = await foodApi.create({
        name: name.trim() || t("customEntry"),
        caloriesPer100g: kcalVal * factor,
        proteinPer100g: proteinVal * factor,
        carbsPer100g: carbsVal * factor,
        fatPer100g: fatVal * factor,
        hidden: true,
      });

      return { food, grams };
    },
    onSuccess: ({ food, grams }) => {
      onAdd({
        foodId: food.id,
        foodName: food.name,
        quantityInGrams: grams,
        caloriesPer100g: food.caloriesPer100g,
        proteinPer100g: food.proteinPer100g,
        carbsPer100g: food.carbsPer100g ?? 0,
        fatPer100g: food.fatPer100g ?? 0,
      });
      setName("");
      setGramsStr("");
      setKcal("");
      setProtein("");
      setCarbs("");
      setFat("");
    },
    onError: () => show(t("addItemFailed"), "error"),
  });

  const canSubmit = kcal.trim() !== "" && protein.trim() !== "" && !createFoodMutation.isPending;

  return (
    <>
      <div className="flex flex-col gap-1">
        <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>{t("name")}</label>
        <input autoFocus value={name} onChange={(e) => setName(e.target.value)}
          placeholder={t("namePlaceholder")}
          className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm"
          style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
      </div>

      <div className="flex flex-col gap-1">
        <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>
          {t("quantityOptional")}
        </label>
        <input type="number" min={1} value={gramsStr} onChange={(e) => setGramsStr(e.target.value)}
          placeholder="100"
          className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm tabular"
          style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div className="flex flex-col gap-1">
          <label className="text-xs font-semibold" style={{ color: "var(--metric-kcal)" }}>{t("caloriesKcal")}</label>
          <input type="number" min={0} value={kcal} onChange={(e) => setKcal(e.target.value)}
            className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm tabular"
            style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
        </div>
        <div className="flex flex-col gap-1">
          <label className="text-xs font-semibold" style={{ color: "var(--metric-protein)" }}>{t("proteinG")}</label>
          <input type="number" min={0} value={protein} onChange={(e) => setProtein(e.target.value)}
            className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm tabular"
            style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
        </div>
        <div className="flex flex-col gap-1">
          <label className="text-xs font-semibold" style={{ color: "var(--metric-carbs)" }}>{t("carbsG")}</label>
          <input type="number" min={0} value={carbs} onChange={(e) => setCarbs(e.target.value)}
            className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm tabular"
            style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
        </div>
        <div className="flex flex-col gap-1">
          <label className="text-xs font-semibold" style={{ color: "var(--metric-fat)" }}>{t("fatG")}</label>
          <input type="number" min={0} value={fat} onChange={(e) => setFat(e.target.value)}
            className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm tabular"
            style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
        </div>
      </div>

      {kcal && protein && (
        <div className="flex gap-4 text-sm tabular px-1">
          <span style={{ color: "var(--metric-kcal)" }}>{Math.round(Number(kcal))} kcal</span>
          <span style={{ color: "var(--metric-protein)" }}>{Math.round(Number(protein))}g P</span>
          {carbs && <span style={{ color: "var(--metric-carbs)" }}>{Math.round(Number(carbs))}g C</span>}
          {fat && <span style={{ color: "var(--metric-fat)" }}>{Math.round(Number(fat))}g F</span>}
        </div>
      )}

      <button onClick={() => createFoodMutation.mutate()} disabled={!canSubmit}
        className="h-10 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-60"
        style={{ background: "var(--primary)", color: "#1E1F18" }}>
        {createFoodMutation.isPending ? t("adding") : t("addItem")}
      </button>
    </>
  );
}
