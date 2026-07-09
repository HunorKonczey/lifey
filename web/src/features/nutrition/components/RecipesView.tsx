"use client";

import { useEffect, useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { recipeApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useDateStore } from "@/lib/hooks/useDateStore";
import { useToast } from "@/lib/hooks/useToast";
import { Skeleton } from "@/components/status/Skeleton";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";
import { RecipeEditor } from "./RecipeEditor";
import { LogRecipeDialog } from "./LogRecipeDialog";
import { RecipeThumbnail } from "./RecipeThumbnail";
import type { RecipeResponse } from "../types";

const PAGE_SIZE = 200;
const SEARCH_DEBOUNCE_MS = 300;

const totalCalories = (r: RecipeResponse) => r.ingredients.reduce((sum, i) => sum + i.calories, 0);
const totalProtein = (r: RecipeResponse) => r.ingredients.reduce((sum, i) => sum + i.protein, 0);

interface RecipesViewProps {
  /** When provided, a "Kiosztás" button appears on every card — admin nav only. */
  onAssign?: (recipe: RecipeResponse) => void;
}

export function RecipesView({ onAssign }: RecipesViewProps = {}) {
  const t = useTranslations("nutrition.recipesView");
  const admin = useTranslations("admin.assignDrawer");
  const { date } = useDateStore();
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [favoritesOnly, setFavoritesOnly] = useState(false);
  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [editing, setEditing] = useState<RecipeResponse | null>(null);
  const [creating, setCreating] = useState(false);
  const [logging, setLogging] = useState<RecipeResponse | null>(null);
  const [duplicating, setDuplicating] = useState<RecipeResponse | null>(null);

  // Debounce the search box so typing doesn't refetch on every keystroke —
  // mirrors FoodsView's search (see FoodsView.tsx).
  useEffect(() => {
    const timeout = setTimeout(() => setDebouncedSearch(search.trim()), SEARCH_DEBOUNCE_MS);
    return () => clearTimeout(timeout);
  }, [search]);

  const pageParams = { page: 0, size: PAGE_SIZE, search: debouncedSearch || undefined };

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.recipes.page(pageParams),
    queryFn: () => recipeApi.page(pageParams),
  });

  const recipes = (data?.content ?? [])
    .filter((r) => !favoritesOnly || r.favorite)
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
      setDuplicating(null);
    },
    onError: () => show(t("duplicateRecipeFailed"), "error"),
  });

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center gap-3">
        <div className="flex items-center gap-2 px-3 h-9 rounded-[var(--r-input)] flex-1 min-w-[180px]"
          style={{ background: "var(--surface)", border: "1px solid var(--outline)" }}
          data-ring-frame>
          <span className="material-symbols-rounded text-base" style={{ color: "var(--muted)" }}>search</span>
          <input
            value={search} onChange={(e) => setSearch(e.target.value)}
            placeholder={t("searchPlaceholder")}
            className="flex-1 min-w-0 bg-transparent outline-none text-sm"
          />
        </div>

        <button onClick={() => setFavoritesOnly((f) => !f)}
          className="flex items-center gap-1 px-3 h-9 rounded-[var(--r-pill)] text-sm font-semibold transition-colors"
          style={{
            background: favoritesOnly ? "var(--primary)" : "var(--surface)",
            color: favoritesOnly ? "#1E1F18" : "var(--on-surface-variant)",
            border: "1px solid var(--outline)",
          }}>
          <span className="material-symbols-rounded text-base"
            style={{ fontVariationSettings: favoritesOnly ? "'FILL' 1" : "'FILL' 0" }}>star</span>
          {t("favorites")}
        </button>

        <button onClick={() => { setCreating(true); setEditing(null); }}
          className="ml-auto flex items-center gap-1 px-4 h-9 rounded-[var(--r-input)] font-semibold text-sm"
          style={{ background: "var(--primary)", color: "#1E1F18" }}>
          <span className="material-symbols-rounded text-lg">add</span> {t("newRecipe")}
        </button>
      </div>

      {isLoading ? (
        <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
          {[0, 1, 2].map((i) => <Skeleton key={i} variant="card" className="h-32" />)}
        </div>
      ) : isError ? (
        <ErrorState onRetry={refetch} />
      ) : recipes.length === 0 ? (
        <EmptyState
          icon="menu_book"
          title={debouncedSearch ? t("noMatch") : t("noRecipes")}
          body={debouncedSearch
            ? t("tryDifferentSearch")
            : t("createToLog")}
        />
      ) : (
        <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
          {recipes.map((r) => (
            <div key={r.id}
              className="flex flex-col gap-2 p-4 rounded-[var(--r-card)] text-left"
              style={{ background: "var(--surface)" }}>
              <button onClick={() => { setEditing(r); setCreating(false); }}
                className="flex gap-3 text-left flex-1">
                <RecipeThumbnail recipeId={r.id} hasImage={r.imageUpdatedAt != null} size={80} />
                <div className="flex flex-col gap-1 min-w-0 flex-1">
                  <div className="flex items-start justify-between gap-2">
                    <p className="font-bold text-sm min-w-0 truncate">{r.name}</p>
                    {r.favorite && (
                      <span className="material-symbols-rounded text-lg shrink-0"
                        style={{ color: "var(--metric-carbs)", fontVariationSettings: "'FILL' 1" }}>star</span>
                    )}
                  </div>
                  {r.description && (
                    <p className="text-xs line-clamp-2" style={{ color: "var(--on-surface-variant)" }}>
                      {r.description}
                    </p>
                  )}
                  <p className="text-xs" style={{ color: "var(--muted)" }}>
                    {r.servings > 1
                      ? t("perServingCaloriesProtein", {
                          calories: Math.round(totalCalories(r) / r.servings),
                          protein: Math.round(totalProtein(r) / r.servings),
                        })
                      : t("totalCaloriesProtein", {
                          calories: Math.round(totalCalories(r)),
                          protein: Math.round(totalProtein(r)),
                        })}
                  </p>
                </div>
              </button>
              <div className="flex gap-1.5 mt-1">
                <button onClick={() => setLogging(r)}
                  className="flex-1 flex items-center justify-center gap-1 h-9 px-3 rounded-[var(--r-input)] text-xs font-semibold transition-colors"
                  style={{ background: "color-mix(in srgb, var(--primary) 15%, transparent)", color: "var(--primary)" }}>
                  <span className="material-symbols-rounded text-base">restaurant</span> {t("logAsMeal")}
                </button>
                <button onClick={() => setDuplicating(r)} disabled={duplicateMutation.isPending}
                  className="flex-1 flex items-center justify-center gap-1 h-9 px-3 rounded-[var(--r-input)] text-xs font-semibold transition-colors disabled:opacity-50"
                  style={{ background: "var(--surface-container)", color: "var(--on-surface-variant)" }}>
                  <span className="material-symbols-rounded text-base">content_copy</span> {t("duplicate")}
                </button>
                {onAssign && (
                  <button onClick={() => onAssign(r)}
                    className="flex-1 flex items-center justify-center gap-1 h-9 px-3 rounded-[var(--r-input)] text-xs font-extrabold transition-colors"
                    style={{ background: "rgba(110,154,106,.18)", color: "var(--tertiary)" }}>
                    <span className="material-symbols-rounded text-base">person_add</span> {admin("assignAction")}
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {(editing || creating) && (
        <RecipeEditor
          key={editing?.id ?? "new"}
          recipe={editing}
          onSaved={() => { setEditing(null); setCreating(false); }}
          onCancel={() => { setEditing(null); setCreating(false); }}
        />
      )}

      {logging && (
        <LogRecipeDialog recipe={logging} date={date} onClose={() => setLogging(null)} />
      )}

      <ConfirmDialog
        open={duplicating !== null}
        title={t("duplicateRecipeConfirmTitle")}
        body={t("duplicateRecipeConfirmBody")}
        confirmLabel={t("duplicate")}
        confirming={duplicateMutation.isPending}
        onConfirm={() => duplicating && duplicateMutation.mutate(duplicating)}
        onCancel={() => setDuplicating(null)}
      />
    </div>
  );
}
