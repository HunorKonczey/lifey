"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { foodApi, mealApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import type { MealType, FoodResponse } from "../types";

interface AddMealEntryDialogProps {
  mealType: MealType;
  date: Date;
  onClose: () => void;
}

type Mode = "search" | "macros";

export function AddMealEntryDialog({ mealType, date, onClose }: AddMealEntryDialogProps) {
  const [mode, setMode] = useState<Mode>("search");

  return (
    <div
      className="fixed inset-0 z-40 flex items-center justify-center p-4"
      style={{ background: "rgba(0,0,0,.5)" }}
      onClick={onClose}
    >
      <div
        className="w-full max-w-md rounded-[var(--r-lg)] p-5 flex flex-col gap-4"
        style={{ background: "var(--surface)" }}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between">
          <h3 className="font-bold text-base capitalize">Add to {mealType.toLowerCase()}</h3>
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

        {mode === "search" ? (
          <SearchMode mealType={mealType} date={date} onClose={onClose} />
        ) : (
          <MacrosMode mealType={mealType} date={date} onClose={onClose} />
        )}
      </div>
    </div>
  );
}

function SearchMode({ mealType, date, onClose }: { mealType: MealType; date: Date; onClose: () => void }) {
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [search, setSearch] = useState("");
  const [picked, setPicked] = useState<FoodResponse | null>(null);
  const [grams, setGrams] = useState(100);

  const { data: foods } = useQuery({ queryKey: queryKeys.foods.all(), queryFn: foodApi.list });

  const matches = (foods ?? [])
    .filter((f) => !f.hidden && f.name.toLowerCase().includes(search.toLowerCase()))
    .slice(0, 8);

  const mutation = useMutation({
    mutationFn: () => {
      const dt = new Date(date);
      dt.setHours(12, 0, 0, 0);
      const now = new Date();
      const dateTime = dt > now ? now : dt;
      return mealApi.create({
        dateTime: dateTime.toISOString(),
        mealType,
        name: null,
        entries: [{ foodId: picked!.id, quantityInGrams: grams }],
      });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.meals.all() });
      show("Added to meal", "success");
      onClose();
    },
    onError: () => show("Failed to add", "error"),
  });

  const previewKcal = picked ? Math.round((picked.caloriesPer100g * grams) / 100) : 0;
  const previewProtein = picked ? Math.round((picked.proteinPer100g * grams) / 100) : 0;

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

      <button onClick={() => mutation.mutate()} disabled={mutation.isPending}
        className="h-10 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-60"
        style={{ background: "var(--primary)", color: "#1E1F18" }}>
        {mutation.isPending ? "Adding…" : "Add to meal"}
      </button>
    </>
  );
}

function MacrosMode({ mealType, date, onClose }: { mealType: MealType; date: Date; onClose: () => void }) {
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [name, setName] = useState("");
  const [gramsStr, setGramsStr] = useState("");
  const [kcal, setKcal] = useState("");
  const [protein, setProtein] = useState("");
  const [carbs, setCarbs] = useState("");
  const [fat, setFat] = useState("");

  const mutation = useMutation({
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

      const dt = new Date(date);
      dt.setHours(12, 0, 0, 0);
      const now = new Date();
      const dateTime = dt > now ? now : dt;
      return mealApi.create({
        dateTime: dateTime.toISOString(),
        mealType,
        name: null,
        entries: [{ foodId: food.id, quantityInGrams: grams }],
      });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.meals.all() });
      show("Added to meal", "success");
      onClose();
    },
    onError: () => show("Failed to add", "error"),
  });

  const canSubmit = kcal.trim() !== "" && protein.trim() !== "" && !mutation.isPending;

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

      <button onClick={() => mutation.mutate()} disabled={!canSubmit}
        className="h-10 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-60"
        style={{ background: "var(--primary)", color: "#1E1F18" }}>
        {mutation.isPending ? "Adding…" : "Add to meal"}
      </button>
    </>
  );
}
