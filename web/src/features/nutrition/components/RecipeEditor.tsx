"use client";

import { useEffect, useRef, useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { Button, Icon, IconButton, NumberField, Switch, TextArea, TextField } from "@/components/ds";
import { Drawer } from "@/components/ds/overlay/Drawer";
import { useFormat } from "@/lib/format/useFormat";
import { foodApi, recipeApi } from "../api";
import { RecipeImageUploader } from "./RecipeImageUploader";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { normalizeForSearch } from "@/lib/utils/search";
import type { RecipeResponse, RecipeIngredientRequest, FoodResponse } from "../types";

interface RecipeEditorProps {
  recipe: RecipeResponse | null;
  onClose: () => void;
  /** Delete the recipe being edited (its id is known once the first auto-save created it) — the parent asks first. */
  onDelete?: (recipeId: number) => void;
}

interface DraftIngredient extends RecipeIngredientRequest {
  foodName: string;
  caloriesPer100g: number;
  proteinPer100g: number;
}

/**
 * The recipe editor (W2.11), a DS `Drawer`: photo, name, description, servings, favourite, the ingredient
 * rows with their grams, the add-ingredient search and the totals. There is no Save button — every valid
 * change is saved automatically (debounced, one request at a time), and the header says so.
 */
export function RecipeEditor({ recipe, onClose, onDelete }: RecipeEditorProps) {
  const t = useTranslations("nutrition.recipeEditor");
  const common = useTranslations("common");
  const fmt = useFormat();
  const queryClient = useQueryClient();
  const { show } = useToast();

  // Remounted via `key` in the parent, so initializing from props is safe here.
  const [name, setName] = useState(recipe?.name ?? "");
  const [description, setDescription] = useState(recipe?.description ?? "");
  const [favorite, setFavorite] = useState(recipe?.favorite ?? false);
  const [servings, setServings] = useState(Math.max(1, recipe?.servings ?? 1));
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

  // A newly added ingredient takes focus so its grams can be typed at once — but not on open.
  const skipFirstFocus = useRef(true);
  useEffect(() => {
    if (skipFirstFocus.current) {
      skipFirstFocus.current = false;
      return;
    }
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

  const saveState = persistMutation.isPending ? t("saving") : canPersist ? t("autoSaved") : t("needsIngredient");

  return (
    <Drawer
      open
      onClose={onClose}
      width={520}
      title={recipe ? t("editRecipe") : t("newRecipe")}
      badge={
        <span role="status" className="type-body-s" style={{ color: "var(--text-3)" }} data-testid="recipe-save-state">
          {saveState}
        </span>
      }
      footer={
        <>
          {recipeId != null && onDelete && (
            <Button variant="ghost" onClick={() => onDelete(recipeId)} aria-label={t("deleteAria")}>
              <Icon name="delete" size={20} color="var(--heart)" />
              {t("delete")}
            </Button>
          )}
          <Button onClick={onClose} className="ml-auto">
            {common("done")}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-5">
        {recipeId != null && <RecipeImageUploader recipeId={recipeId} />}

        <TextField
          label={t("name")}
          size="dense"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder={t("namePlaceholder")}
          autoFocus={!recipe}
          required
        />

        <TextArea
          label={t("description")}
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder={t("descriptionPlaceholder")}
          rows={2}
        />

        <div className="flex flex-wrap items-end gap-x-6 gap-y-3">
          <NumberField
            label={t("servings")}
            size="dense"
            className="w-40"
            value={servings}
            onChange={(v) => setServings(Math.max(1, Math.round(v)))}
            min={1}
            max={99}
            maxDecimals={0}
            selectOnFocus
          />
          <div className="pb-2.5">
            <Switch checked={favorite} onChange={setFavorite} label={t("favorite")} />
          </div>
        </div>

        {/* Ingredients */}
        <div className="flex flex-col gap-2">
          <p className="type-label" style={{ color: "var(--text-3)", fontWeight: 700 }}>
            {t("ingredients")}
          </p>
          {ingredients.map((ing, idx) => (
            <div
              key={idx}
              className="flex items-center gap-3 px-3 py-2"
              style={{ background: "var(--nested)", borderRadius: "var(--r-control)" }}
              data-testid="recipe-ingredient"
            >
              <div className="flex min-w-0 flex-1 flex-col">
                <span className="type-body-s truncate" style={{ fontWeight: 700 }}>
                  {ing.foodName}
                </span>
                <span className="type-label tabular flex gap-2">
                  <span style={{ color: "var(--m-kcal)" }}>
                    {fmt.integer((ing.caloriesPer100g * ing.quantityInGrams) / 100)} kcal
                  </span>
                  <span style={{ color: "var(--m-protein)" }}>
                    {fmt.integer((ing.proteinPer100g * ing.quantityInGrams) / 100)} g P
                  </span>
                </span>
              </div>
              <NumberField
                aria-label={ing.foodName}
                size="dense"
                className="w-36"
                unit="g"
                value={ing.quantityInGrams}
                onChange={(v) => setIngredients((prev) => prev.map((x, i) => (i === idx ? { ...x, quantityInGrams: Math.max(0, v) } : x)))}
                min={0}
                step={5}
                inputRef={(el) => {
                  gramsRefs.current[idx] = el;
                }}
                liveUpdate
                selectOnFocus
              />
              <IconButton
                icon="close"
                label={t("removeIngredientAria")}
                onClick={() => setIngredients((prev) => prev.filter((_, i) => i !== idx))}
              />
            </div>
          ))}

          {/* Ingredient picker */}
          <TextField
            size="dense"
            leadingIcon="add"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder={t("addIngredientPlaceholder")}
            aria-label={t("addIngredientPlaceholder")}
          />
          {search && (
            <div className="flex flex-col gap-1">
              {matches.map((f) => (
                <button
                  key={f.id}
                  type="button"
                  onClick={() => addIngredient(f)}
                  className="lifey-button type-body-s flex items-center justify-between gap-2 px-3 py-2 text-left"
                  style={{ borderRadius: "var(--r-control)" }}
                >
                  <span className="truncate">{f.name}</span>
                  <span className="type-label tabular flex shrink-0 gap-2">
                    <span style={{ color: "var(--m-kcal)" }}>{fmt.integer(f.caloriesPer100g)} kcal</span>
                    <span style={{ color: "var(--m-protein)" }}>{fmt.integer(f.proteinPer100g)} g P</span>
                  </span>
                </button>
              ))}
            </div>
          )}
        </div>

        <div className="type-body-s tabular flex flex-wrap justify-between gap-x-4 gap-y-1 pt-3" style={{ borderTop: "1px solid var(--hairline)" }}>
          <span style={{ color: "var(--text-2)" }}>{t("total")}</span>
          <span style={{ color: "var(--m-kcal)", fontWeight: 700 }}>
            {t("totalPerServingKcal", { total: Math.round(totalKcal), perServing: Math.round(totalKcal / servings) })}
          </span>
          <span style={{ color: "var(--m-protein)", fontWeight: 700 }}>
            {t("totalPerServingProtein", { total: Math.round(totalProtein), perServing: Math.round(totalProtein / servings) })}
          </span>
        </div>
      </div>
    </Drawer>
  );
}
