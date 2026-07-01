"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { foodApi, mealApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { logTimestampFor } from "@/lib/utils/logTime";
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
  const queryClient = useQueryClient();
  const { show } = useToast();
  const isEditing = meal != null;
  const [mode, setMode] = useState<Mode>("search");
  const [items, setItems] = useState<DraftItem[]>(() => (meal ? draftItemsFromMeal(meal) : []));

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
      show(isEditing ? "Meal updated" : "Meal saved", "success");
      onClose();
    },
    onError: () => show(isEditing ? "Failed to update meal" : "Failed to save meal", "error"),
  });

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
          <h3 className="font-bold text-base capitalize">
            {isEditing ? `Edit ${mealType.toLowerCase()}` : `Add to ${mealType.toLowerCase()}`}
          </h3>
          <button onClick={onClose} aria-label="Close"
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
              {m === "search" ? "Search food" : "Enter macros"}
            </button>
          ))}
        </div>

        {mode === "search" ? <SearchMode onAdd={addItem} /> : <MacrosMode onAdd={addItem} />}

        {/* Items added so far */}
        {items.length > 0 && (
          <div className="flex flex-col gap-2 pt-2" style={{ borderTop: "1px solid var(--outline)" }}>
            <p className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>
              Items ({items.length})
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
                <button onClick={() => removeItem(idx)} style={{ color: "var(--muted)" }} aria-label="Remove item">
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
            ? "Saving…"
            : isEditing
              ? "Save changes"
              : `Save meal${items.length > 0 ? ` (${items.length})` : ""}`}
        </button>
      </div>
    </div>
  );
}

function SearchMode({ onAdd }: { onAdd: (item: DraftItem) => void }) {
  const [search, setSearch] = useState("");
  const [picked, setPicked] = useState<FoodResponse | null>(null);
  const [grams, setGrams] = useState(100);

  const { data: foods } = useQuery({ queryKey: queryKeys.foods.all(), queryFn: foodApi.list });

  const matches = (foods ?? [])
    .filter((f) => !f.hidden && f.name.toLowerCase().includes(search.toLowerCase()))
    .slice(0, 8);

  const previewKcal = picked ? Math.round((picked.caloriesPer100g * grams) / 100) : 0;
  const previewProtein = picked ? Math.round((picked.proteinPer100g * grams) / 100) : 0;

  const addAndReset = () => {
    if (!picked) return;
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
    setGrams(100);
  };

  if (!picked) {
    return (
      <>
        <div className="flex items-center gap-2 px-3 h-10 rounded-[var(--r-input)]"
          style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}>
          <span className="material-symbols-rounded text-base" style={{ color: "var(--muted)" }}>search</span>
          <input autoFocus value={search} onChange={(e) => setSearch(e.target.value)}
            placeholder="Search foods…" className="flex-1 bg-transparent outline-none text-sm" />
        </div>
        <div className="flex flex-col gap-1 max-h-64 overflow-y-auto">
          {matches.map((f) => (
            <button key={f.id} onClick={() => setPicked(f)}
              className="flex items-center justify-between px-3 py-2 rounded-[var(--r-md)] text-left transition-colors hover:bg-surface-container">
              <span className="text-sm font-semibold">{f.name}</span>
              <span className="text-xs tabular" style={{ color: "var(--metric-kcal)" }}>
                {Math.round(f.caloriesPer100g)} kcal/100g
              </span>
            </button>
          ))}
          {search && matches.length === 0 && (
            <p className="text-sm text-center py-4" style={{ color: "var(--muted)" }}>No matches</p>
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
          Change
        </button>
      </div>

      <div className="flex flex-col gap-1">
        <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>Quantity (g)</label>
        <input type="number" value={grams} min={1}
          onChange={(e) => setGrams(Math.max(1, Number(e.target.value)))}
          className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm tabular"
          style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
      </div>

      <div className="flex gap-4 text-sm tabular">
        <span style={{ color: "var(--metric-kcal)" }}>{previewKcal} kcal</span>
        <span style={{ color: "var(--metric-protein)" }}>{previewProtein}g protein</span>
      </div>

      <button onClick={addAndReset}
        className="h-10 rounded-[var(--r-input)] font-semibold text-sm transition-opacity"
        style={{ background: "var(--primary)", color: "#1E1F18" }}>
        Add item
      </button>
    </>
  );
}

function MacrosMode({ onAdd }: { onAdd: (item: DraftItem) => void }) {
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
        name: name.trim() || "Custom entry",
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
    onError: () => show("Failed to add item", "error"),
  });

  const canSubmit = kcal.trim() !== "" && protein.trim() !== "" && !createFoodMutation.isPending;

  return (
    <>
      <div className="flex flex-col gap-1">
        <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>Name</label>
        <input autoFocus value={name} onChange={(e) => setName(e.target.value)}
          placeholder="e.g. Lunch at restaurant"
          className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm"
          style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
      </div>

      <div className="flex flex-col gap-1">
        <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>
          Quantity (g) <span style={{ color: "var(--muted)", fontWeight: 400 }}>— optional, defaults to 100</span>
        </label>
        <input type="number" min={1} value={gramsStr} onChange={(e) => setGramsStr(e.target.value)}
          placeholder="100"
          className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm tabular"
          style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div className="flex flex-col gap-1">
          <label className="text-xs font-semibold" style={{ color: "var(--metric-kcal)" }}>Calories (kcal) *</label>
          <input type="number" min={0} value={kcal} onChange={(e) => setKcal(e.target.value)}
            className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm tabular"
            style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
        </div>
        <div className="flex flex-col gap-1">
          <label className="text-xs font-semibold" style={{ color: "var(--metric-protein)" }}>Protein (g) *</label>
          <input type="number" min={0} value={protein} onChange={(e) => setProtein(e.target.value)}
            className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm tabular"
            style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
        </div>
        <div className="flex flex-col gap-1">
          <label className="text-xs font-semibold" style={{ color: "var(--metric-carbs)" }}>Carbs (g)</label>
          <input type="number" min={0} value={carbs} onChange={(e) => setCarbs(e.target.value)}
            className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm tabular"
            style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
        </div>
        <div className="flex flex-col gap-1">
          <label className="text-xs font-semibold" style={{ color: "var(--metric-fat)" }}>Fat (g)</label>
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
        {createFoodMutation.isPending ? "Adding…" : "Add item"}
      </button>
    </>
  );
}
