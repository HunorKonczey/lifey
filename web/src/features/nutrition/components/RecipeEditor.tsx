"use client";

import { useEffect, useRef, useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { foodApi, recipeApi } from "../api";
import { RecipeImageUploader } from "./RecipeImageUploader";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { normalizeForSearch } from "@/lib/utils/search";
import type { RecipeResponse, RecipeIngredientRequest, FoodResponse } from "../types";

interface RecipeEditorProps {
  recipe: RecipeResponse | null;
  onClose: () => void;
}

interface DraftIngredient extends RecipeIngredientRequest {
  foodName: string;
  caloriesPer100g: number;
  proteinPer100g: number;
}

export function RecipeEditor({ recipe, onClose }: RecipeEditorProps) {
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
  const gramsRefs = useRef<(HTMLInputElement | null)[]>([]);
  // The recipe this editor is persisting to — the prop's id when editing, or
  // whatever id got created by the first auto-save otherwise.
  const [recipeId, setRecipeId] = useState<number | null>(recipe?.id ?? null);

  const { data: foods } = useQuery({ queryKey: queryKeys.foods.all(), queryFn: foodApi.list });

  const matches = (foods ?? [])
    .filter((f) => !f.hidden && normalizeForSearch(f.name).includes(normalizeForSearch(search)))
    .slice(0, 6);

  const addIngredient = (f: FoodResponse) => {
    setIngredients((prev) => [
      ...prev,
      { foodId: f.id, quantityInGrams: 0, foodName: f.name, caloriesPer100g: f.caloriesPer100g, proteinPer100g: f.proteinPer100g },
    ]);
    setSearch("");
  };

  useEffect(() => {
    const last = gramsRefs.current[ingredients.length - 1];
    if (last) {
      last.focus();
      last.select();
    }
  }, [ingredients.length]);

  const totalKcal = ingredients.reduce(
    (s, i) => s + (i.caloriesPer100g * i.quantityInGrams) / 100, 0,
  );
  const totalProtein = ingredients.reduce(
    (s, i) => s + (i.proteinPer100g * i.quantityInGrams) / 100, 0,
  );

  // A recipe needs a name and at least one fully-quantified ingredient
  // before the backend will accept it (name is @NotBlank, each ingredient's
  // quantityInGrams is @Positive) — matches the guard the old manual Save
  // button used, now driving auto-save instead.
  const canPersist = name.trim().length > 0 && ingredients.length > 0 && ingredients.every((i) => i.quantityInGrams > 0);

  const persistMutation = useMutation({
    mutationFn: () => {
      const body = {
        name, description: description || null, favorite, servings,
        ingredients: ingredients.map((i) => ({ foodId: i.foodId, quantityInGrams: i.quantityInGrams })),
      };
      return recipeId != null ? recipeApi.update(recipeId, body) : recipeApi.create(body);
    },
    onSuccess: (result) => {
      setRecipeId(result.id);
      queryClient.invalidateQueries({ queryKey: queryKeys.recipes.all() });
    },
    onError: () => show(t("saveFailed"), "error"),
  });

  // Persists are serialized (never more than one in flight): a change that
  // arrives mid-save is queued and re-run with the latest snapshot once the
  // in-flight one settles, so two rapid changes can't each try to create
  // their own recipe.
  const isPersisting = useRef(false);
  const pendingPersist = useRef(false);

  const runPersist = async () => {
    isPersisting.current = true;
    try {
      await persistMutation.mutateAsync();
    } catch {
      // already surfaced via persistMutation's onError
    } finally {
      isPersisting.current = false;
      if (pendingPersist.current) {
        pendingPersist.current = false;
        runPersist();
      }
    }
  };

  const schedulePersist = () => {
    if (isPersisting.current) {
      pendingPersist.current = true;
      return;
    }
    runPersist();
  };

  // Auto-save: debounced so a burst of edits (typing a name, nudging
  // servings) collapses into one request, and skipped on the very first
  // render so opening an existing recipe doesn't immediately re-save it.
  const skipFirstPersist = useRef(true);
  const persistTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (skipFirstPersist.current) {
      skipFirstPersist.current = false;
      return;
    }
    if (!canPersist) return;
    if (persistTimer.current) clearTimeout(persistTimer.current);
    persistTimer.current = setTimeout(schedulePersist, 400);
    return () => {
      if (persistTimer.current) clearTimeout(persistTimer.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [name, description, favorite, servings, ingredients, canPersist]);

  const deleteMutation = useMutation({
    mutationFn: () => recipeApi.delete(recipeId!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.recipes.all() });
      show(t("deleted"), "success");
      onClose();
    },
    onError: () => show(t("deleteFailed"), "error"),
  });

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center p-4"
      style={{ background: "rgba(0,0,0,.5)" }} onClick={onClose}>
      <div className="w-full max-w-lg rounded-[var(--r-lg)] p-5 flex flex-col gap-4 max-h-[90vh] overflow-y-auto"
        style={{ background: "var(--surface)" }} onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between">
          <h3 className="font-bold text-base">{recipe ? t("editRecipe") : t("newRecipe")}</h3>
          <div className="flex items-center gap-2">
            {persistMutation.isPending && (
              <span className="text-xs" style={{ color: "var(--on-surface-variant)" }}>{common("saving")}</span>
            )}
            <button onClick={onClose} aria-label={common("close")} className="p-1 rounded-[var(--r-sm)]">
              <span className="material-symbols-rounded">close</span>
            </button>
          </div>
        </div>

        {recipeId != null && <RecipeImageUploader recipeId={recipeId} />}

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
              <div className="flex-1 min-w-0 flex flex-col">
                <span className="text-sm font-semibold truncate">{ing.foodName}</span>
                <span className="flex gap-2 text-xs tabular">
                  <span style={{ color: "var(--metric-kcal)" }}>
                    {Math.round((ing.caloriesPer100g * ing.quantityInGrams) / 100)} kcal
                  </span>
                  <span style={{ color: "var(--metric-protein)" }}>
                    {Math.round((ing.proteinPer100g * ing.quantityInGrams) / 100)}g P
                  </span>
                </span>
              </div>
              <input type="number" min={1} placeholder="100"
                value={ing.quantityInGrams === 0 ? "" : ing.quantityInGrams}
                ref={(el) => { gramsRefs.current[idx] = el; }}
                onChange={(e) => setIngredients((prev) =>
                  prev.map((x, i) => i === idx
                    ? { ...x, quantityInGrams: e.target.value === "" ? 0 : Math.max(1, Number(e.target.value)) }
                    : x))}
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
                  className="flex items-center justify-between gap-2 px-3 py-1.5 rounded-[var(--r-sm)] text-sm transition-colors hover:bg-surface-container">
                  <span className="truncate">{f.name}</span>
                  <span className="flex gap-2 text-xs tabular shrink-0">
                    <span style={{ color: "var(--metric-kcal)" }}>{Math.round(f.caloriesPer100g)} kcal</span>
                    <span style={{ color: "var(--metric-protein)" }}>{Math.round(f.proteinPer100g)}g P</span>
                  </span>
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

        {recipeId != null && (
          <button onClick={() => deleteMutation.mutate()} disabled={deleteMutation.isPending}
            className="h-10 rounded-[var(--r-input)] font-semibold text-sm"
            style={{ background: "color-mix(in srgb, var(--error) 15%, transparent)", color: "var(--error)" }}
            aria-label={t("deleteAria")}>
            <span className="material-symbols-rounded text-xl align-middle">delete</span>
          </button>
        )}
      </div>
    </div>
  );
}
