"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { Button, ConfirmModal, Icon, TextField } from "@/components/ds";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";
import { queryKeys } from "@/lib/api/queryKeys";
import { useDateStore } from "@/lib/hooks/useDateStore";
import { TOAST_DURATION_MS, useToast } from "@/lib/hooks/useToast";
import { useUndoableDelete } from "@/lib/hooks/useUndoableDelete";
import { foodApi, recipeApi } from "../api";
import { matchesFoodSearch } from "../foodsTable";
import { recipeTotals, type Macros } from "../recipeMacros";
import type { FoodResponse, RecipeResponse } from "../types";
import { LogRecipeDialog } from "./LogRecipeDialog";
import { RecipeCard } from "./RecipeCard";
import { RecipeEditor } from "./RecipeEditor";
import { RecipeThumbnail } from "./RecipeThumbnail";

interface RecipesViewProps {
  /** When provided, "Kiosztás" is the first item of every card's "⋯" — admin nav only. */
  onAssign?: (recipe: RecipeResponse) => void;
  /** Controlled "new recipe" state, for a page that owns the button (the nutrition tab row). Without
   *  it the view draws its own "＋ Új recept" beside the search. */
  creating?: boolean;
  onCreatingChange?: (creating: boolean) => void;
}

/** One serving's macros: the recipe's total over its servings. */
function perServing(recipe: RecipeResponse, foodsById: ReadonlyMap<number, FoodResponse>): Macros {
  const total = recipeTotals(recipe, foodsById);
  const k = 1 / Math.max(recipe.servings, 1);
  return { calories: total.calories * k, protein: total.protein * k, carbs: total.carbs * k, fat: total.fat * k };
}

/**
 * The recipes tab (W2.11, W2-E): a search box, a Favorites chip and a grid of `RecipeCard`s — one column on a
 * narrow pane, two, then three as it widens (container queries, so the page's sidebar is accounted for).
 * Works on the whole recipe list (the query the tab's count already uses) and the food list for carbs and fat,
 * which the recipe API doesn't carry per ingredient.
 */
export function RecipesView({ onAssign, creating: creatingProp, onCreatingChange }: RecipesViewProps = {}) {
  const t = useTranslations("nutrition.recipesView");
  const admin = useTranslations("admin.assignDrawer");
  const common = useTranslations("common");
  const { date } = useDateStore();
  const queryClient = useQueryClient();
  const { show } = useToast();
  const undoableDelete = useUndoableDelete();
  const [favoritesOnly, setFavoritesOnly] = useState(false);
  const [search, setSearch] = useState("");
  const [editing, setEditing] = useState<RecipeResponse | null>(null);
  const [creatingLocal, setCreatingLocal] = useState(false);
  const [logging, setLogging] = useState<RecipeResponse | null>(null);
  const [deleting, setDeleting] = useState<RecipeResponse | null>(null);

  const controlled = creatingProp !== undefined;
  const creating = controlled ? creatingProp : creatingLocal;
  const setCreating = (next: boolean) => (controlled ? onCreatingChange?.(next) : setCreatingLocal(next));

  const { data, isLoading, isError, refetch } = useQuery({ queryKey: queryKeys.recipes.all(), queryFn: recipeApi.list });
  const { data: foods, isLoading: foodsLoading } = useQuery({ queryKey: queryKeys.foods.all(), queryFn: foodApi.list });
  const foodsById = new Map((foods ?? []).map((f) => [f.id, f]));

  const recipes = (data ?? [])
    .filter((r) => (!favoritesOnly || r.favorite) && matchesFoodSearch(r.name, search))
    .sort((a, b) => (a.favorite === b.favorite ? a.name.localeCompare(b.name) : a.favorite ? -1 : 1));

  const duplicateMutation = useMutation({
    mutationFn: (recipe: RecipeResponse) =>
      recipeApi.create({
        name: t("copyOf", { name: recipe.name }),
        description: recipe.description,
        favorite: recipe.favorite,
        servings: recipe.servings,
        ingredients: recipe.ingredients.map((i) => ({ foodId: i.foodId, quantityInGrams: i.quantityInGrams })),
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.recipes.all() });
      show(t("recipeDuplicated"), "success");
    },
    onError: () => show(t("duplicateRecipeFailed"), "error"),
  });

  const setCachedRecipes = (update: (list: RecipeResponse[]) => RecipeResponse[]) =>
    queryClient.setQueryData<RecipeResponse[]>(queryKeys.recipes.all(), (old) => update(old ?? []));

  // Delete = confirm → the card leaves the grid and a toast offers Undo; the DELETE goes out when the window closes.
  const deleteRecipe = (recipe: RecipeResponse) => {
    // Deleting from the editor (also a just-created recipe) closes it; the toast then offers Undo.
    setEditing(null);
    setCreating(false);
    undoableDelete({
      message: t("recipeDeleted", { name: recipe.name }),
      path: `/recipes/${recipe.id}`,
      remove: () => setCachedRecipes((list) => list.filter((r) => r.id !== recipe.id)),
      restore: () => setCachedRecipes((list) => (list.some((r) => r.id === recipe.id) ? list : [...list, recipe])),
      errorMessage: t("deleteFailed"),
    });
  };

  const menuFor = (r: RecipeResponse) => [
    ...(onAssign ? [{ label: admin("assignAction"), icon: "person_add", onSelect: () => onAssign(r) }] : []),
    { label: t("menuEdit"), icon: "edit", onSelect: () => setEditing(r) },
    { label: t("menuDuplicate"), icon: "content_copy", onSelect: () => duplicateMutation.mutate(r) },
    { label: t("menuDelete"), icon: "delete", destructive: true, onSelect: () => setDeleting(r) },
  ];

  const newButton = (
    <Button onClick={() => setCreating(true)} className="ml-auto">
      <Icon name="add" size={20} />
      {t("newRecipe")}
    </Button>
  );

  return (
    <div className="flex flex-col gap-4 @container">
      <div className="flex flex-wrap items-center gap-3">
        <TextField
          size="dense"
          leadingIcon="search"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder={t("searchPlaceholder")}
          aria-label={t("searchPlaceholder")}
          className="min-w-[200px] flex-1 sm:max-w-xs"
        />
        <button
          type="button"
          aria-pressed={favoritesOnly}
          onClick={() => setFavoritesOnly((f) => !f)}
          className="lifey-button type-body-s inline-flex items-center gap-1.5"
          style={{
            height: 30,
            padding: "0 12px",
            borderRadius: "var(--r-pill)",
            fontWeight: 700,
            background: favoritesOnly ? "var(--primary)" : "var(--nested)",
            color: favoritesOnly ? "var(--on-primary)" : "var(--text-2)",
          }}
        >
          <Icon name="star" size={16} fill={favoritesOnly ? 1 : 0} />
          {t("favorites")}
        </button>
        {!controlled && newButton}
      </div>

      {isLoading || foodsLoading ? (
        <div className="grid grid-cols-1 gap-4 @[560px]:grid-cols-2 @[840px]:grid-cols-3">
          {[0, 1, 2].map((i) => (
            <Skeleton key={i} variant="card" className="h-48" />
          ))}
        </div>
      ) : isError ? (
        <ErrorState onRetry={refetch} />
      ) : recipes.length === 0 ? (
        <EmptyState
          icon="menu_book"
          title={search.trim() || favoritesOnly ? t("noMatch") : t("noRecipes")}
          body={search.trim() || favoritesOnly ? t("tryDifferentSearch") : t("createToLog")}
          action={
            !search.trim() && !favoritesOnly ? (
              <Button onClick={() => setCreating(true)}>
                <Icon name="add" size={20} />
                {t("newRecipe")}
              </Button>
            ) : undefined
          }
        />
      ) : (
        <div className="grid grid-cols-1 gap-4 @[560px]:grid-cols-2 @[840px]:grid-cols-3" data-testid="recipe-grid">
          {recipes.map((r) => (
            <RecipeCard
              key={r.id}
              recipe={r}
              perServing={perServing(r, foodsById)}
              photo={r.imageUpdatedAt != null ? <RecipeThumbnail recipeId={r.id} hasImage size={56} /> : undefined}
              onOpen={() => setEditing(r)}
              onLog={() => setLogging(r)}
              menu={menuFor(r)}
            />
          ))}
        </div>
      )}

      {(editing || creating) && (
        <RecipeEditor
          key={editing?.id ?? "new"}
          recipe={editing}
          onClose={() => {
            setEditing(null);
            setCreating(false);
          }}
          onDelete={(id) => {
            const target = (queryClient.getQueryData<RecipeResponse[]>(queryKeys.recipes.all()) ?? []).find((r) => r.id === id);
            if (target) setDeleting(target);
          }}
        />
      )}

      {logging && <LogRecipeDialog recipe={logging} date={date} onClose={() => setLogging(null)} />}

      <ConfirmModal
        open={deleting != null}
        onClose={() => setDeleting(null)}
        onConfirm={() => {
          if (deleting) deleteRecipe(deleting);
          setDeleting(null);
        }}
        icon="delete"
        title={deleting ? t("deleteTitle", { name: deleting.name }) : ""}
        body={deleting ? t("deleteBody", { seconds: TOAST_DURATION_MS / 1000 }) : ""}
        cancelLabel={common("cancel")}
        confirmLabel={common("delete")}
      />
    </div>
  );
}
