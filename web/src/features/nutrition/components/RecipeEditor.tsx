"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { foodApi, recipeApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import type { RecipeResponse, RecipeIngredientRequest, FoodResponse } from "../types";

interface RecipeEditorProps {
  recipe: RecipeResponse | null;
  onSaved: () => void;
  onCancel: () => void;
}

interface DraftIngredient extends RecipeIngredientRequest {
  foodName: string;
  caloriesPer100g: number;
  proteinPer100g: number;
}

export function RecipeEditor({ recipe, onSaved, onCancel }: RecipeEditorProps) {
  const t = useTranslations("nutrition.recipeEditor");
  const common = useTranslations("common");
  const queryClient = useQueryClient();
  const { show } = useToast();

  // Remounted via `key` in the parent, so initializing from props is safe here.
  const [name, setName] = useState(recipe?.name ?? "");
  const [description, setDescription] = useState(recipe?.description ?? "");
  const [favorite, setFavorite] = useState(recipe?.favorite ?? false);
  const [servingsText, setServingsText] = useState(String(recipe?.servings ?? 1));
  const servings = Math.max(1, Number(servingsText) || 1);
  const [ingredients, setIngredients] = useState<DraftIngredient[]>(
    recipe
      ? recipe.ingredients.map((i) => ({
          foodId: i.foodId, quantityInGrams: i.quantityInGrams,
          foodName: i.foodName,
          caloriesPer100g: i.quantityInGrams > 0 ? (i.calories * 100) / i.quantityInGrams : 0,
          proteinPer100g: i.quantityInGrams > 0 ? (i.protein * 100) / i.quantityInGrams : 0,
        }))
      : [],
  );
  const [search, setSearch] = useState("");

  const { data: foods } = useQuery({ queryKey: queryKeys.foods.all(), queryFn: foodApi.list });

  const matches = (foods ?? [])
    .filter((f) => !f.hidden && f.name.toLowerCase().includes(search.toLowerCase()))
    .slice(0, 6);

  const addIngredient = (f: FoodResponse) => {
    setIngredients((prev) => [
      ...prev,
      { foodId: f.id, quantityInGrams: 100, foodName: f.name, caloriesPer100g: f.caloriesPer100g, proteinPer100g: f.proteinPer100g },
    ]);
    setSearch("");
  };

  const totalKcal = ingredients.reduce(
    (s, i) => s + (i.caloriesPer100g * i.quantityInGrams) / 100, 0,
  );
  const totalProtein = ingredients.reduce(
    (s, i) => s + (i.proteinPer100g * i.quantityInGrams) / 100, 0,
  );

  const mutation = useMutation({
    mutationFn: () => {
      const body = {
        name, description: description || null, favorite, servings,
        ingredients: ingredients.map((i) => ({ foodId: i.foodId, quantityInGrams: i.quantityInGrams })),
      };
      return recipe ? recipeApi.update(recipe.id, body) : recipeApi.create(body);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.recipes.all() });
      show(recipe ? t("updated") : t("created"), "success");
      onSaved();
    },
    onError: () => show(t("saveFailed"), "error"),
  });

  const deleteMutation = useMutation({
    mutationFn: () => recipeApi.delete(recipe!.id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.recipes.all() });
      show(t("deleted"), "success");
      onSaved();
    },
    onError: () => show(t("deleteFailed"), "error"),
  });

  const canSave = name.trim() && ingredients.length > 0;

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center p-4"
      style={{ background: "rgba(0,0,0,.5)" }} onClick={onCancel}>
      <div className="w-full max-w-lg rounded-[var(--r-lg)] p-5 flex flex-col gap-4 max-h-[90vh] overflow-y-auto"
        style={{ background: "var(--surface)" }} onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between">
          <h3 className="font-bold text-base">{recipe ? t("editRecipe") : t("newRecipe")}</h3>
          <button onClick={onCancel} aria-label={common("close")} className="p-1 rounded-[var(--r-sm)]">
            <span className="material-symbols-rounded">close</span>
          </button>
        </div>

        <input value={name} onChange={(e) => setName(e.target.value)} placeholder={t("namePlaceholder")}
          className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm font-semibold"
          style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />

        <textarea value={description} onChange={(e) => setDescription(e.target.value)}
          placeholder={t("descriptionPlaceholder")} rows={2}
          className="px-3 py-2 rounded-[var(--r-input)] outline-none text-sm resize-none"
          style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />

        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2">
            <label className="text-sm font-semibold">{t("servings")}</label>
            <input type="number" min={1} value={servingsText}
              onChange={(e) => setServingsText(e.target.value)}
              onBlur={() => setServingsText(String(servings))}
              className="w-16 px-2 h-9 rounded-[var(--r-md)] outline-none text-sm tabular"
              style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
          </div>
          <button onClick={() => setFavorite((f) => !f)} className="flex items-center gap-1 text-sm font-semibold">
            <span className="material-symbols-rounded text-xl"
              style={{ color: favorite ? "var(--metric-carbs)" : "var(--muted)", fontVariationSettings: favorite ? "'FILL' 1" : "'FILL' 0" }}>
              star
            </span>
            {t("favorite")}
          </button>
        </div>

        {/* Ingredients */}
        <div className="flex flex-col gap-2">
          <p className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>{t("ingredients")}</p>
          {ingredients.map((ing, idx) => (
            <div key={idx} className="flex items-center gap-2 px-3 py-2 rounded-[var(--r-md)]"
              style={{ background: "var(--surface-container)" }}>
              <span className="flex-1 text-sm font-semibold">{ing.foodName}</span>
              <input type="number" min={1} value={ing.quantityInGrams}
                onChange={(e) => setIngredients((prev) =>
                  prev.map((x, i) => i === idx ? { ...x, quantityInGrams: Math.max(1, Number(e.target.value)) } : x))}
                className="w-16 px-2 h-8 rounded-[var(--r-sm)] outline-none text-sm tabular"
                style={{ background: "var(--surface)", border: "1px solid var(--outline)" }} />
              <span className="text-xs" style={{ color: "var(--muted)" }}>g</span>
              <button onClick={() => setIngredients((prev) => prev.filter((_, i) => i !== idx))}
                style={{ color: "var(--muted)" }} aria-label={t("removeIngredientAria")}>
                <span className="material-symbols-rounded text-lg">close</span>
              </button>
            </div>
          ))}

          {/* Ingredient picker */}
          <div className="flex items-center gap-2 px-3 h-9 rounded-[var(--r-md)]"
            style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}
            data-ring-frame>
            <span className="material-symbols-rounded text-base" style={{ color: "var(--muted)" }}>add</span>
            <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder={t("addIngredientPlaceholder")}
              className="flex-1 min-w-0 bg-transparent outline-none text-sm" />
          </div>
          {search && (
            <div className="flex flex-col gap-1">
              {matches.map((f) => (
                <button key={f.id} onClick={() => addIngredient(f)}
                  className="text-left px-3 py-1.5 rounded-[var(--r-sm)] text-sm transition-colors hover:bg-surface-container">
                  {f.name}
                </button>
              ))}
            </div>
          )}
        </div>

        <div className="flex justify-between text-sm tabular pt-2" style={{ borderTop: "1px solid var(--outline)" }}>
          <span style={{ color: "var(--on-surface-variant)" }}>{t("total")}</span>
          <span className="font-semibold" style={{ color: "var(--metric-kcal)" }}>
            {Math.round(totalKcal)} kcal · {Math.round(totalKcal / servings)} / serving
          </span>
          <span className="font-semibold" style={{ color: "var(--metric-protein)" }}>
            {Math.round(totalProtein)}g protein · {Math.round(totalProtein / servings)}g / serving
          </span>
        </div>

        <div className="flex gap-2">
          <button onClick={() => mutation.mutate()} disabled={!canSave || mutation.isPending}
            className="flex-1 h-10 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-50"
            style={{ background: "var(--primary)", color: "#1E1F18" }}>
            {mutation.isPending ? common("saving") : t("saveRecipe")}
          </button>
          {recipe && (
            <button onClick={() => deleteMutation.mutate()} disabled={deleteMutation.isPending}
              className="px-4 h-10 rounded-[var(--r-input)] font-semibold text-sm"
              style={{ background: "color-mix(in srgb, var(--error) 15%, transparent)", color: "var(--error)" }}
              aria-label={t("deleteAria")}>
              <span className="material-symbols-rounded text-xl">delete</span>
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
