"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { recipeApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { Skeleton } from "@/components/status/Skeleton";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { RecipeEditor } from "./RecipeEditor";
import type { RecipeResponse } from "../types";

export function RecipesView() {
  const [favoritesOnly, setFavoritesOnly] = useState(false);
  const [editing, setEditing] = useState<RecipeResponse | null>(null);
  const [creating, setCreating] = useState(false);

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.recipes.all(),
    queryFn: recipeApi.list,
  });

  const recipes = (data ?? []).filter((r) => !favoritesOnly || r.favorite);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center gap-3">
        <button onClick={() => setFavoritesOnly((f) => !f)}
          className="flex items-center gap-1 px-3 h-9 rounded-[var(--r-pill)] text-sm font-semibold transition-colors"
          style={{
            background: favoritesOnly ? "var(--primary)" : "var(--surface)",
            color: favoritesOnly ? "#1E1F18" : "var(--on-surface-variant)",
            border: "1px solid var(--outline)",
          }}>
          <span className="material-symbols-rounded text-base"
            style={{ fontVariationSettings: favoritesOnly ? "'FILL' 1" : "'FILL' 0" }}>star</span>
          Favorites
        </button>

        <button onClick={() => { setCreating(true); setEditing(null); }}
          className="ml-auto flex items-center gap-1 px-4 h-9 rounded-[var(--r-input)] font-semibold text-sm"
          style={{ background: "var(--primary)", color: "#1E1F18" }}>
          <span className="material-symbols-rounded text-lg">add</span> New recipe
        </button>
      </div>

      {isLoading ? (
        <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
          {[0, 1, 2].map((i) => <Skeleton key={i} variant="card" className="h-32" />)}
        </div>
      ) : isError ? (
        <ErrorState onRetry={refetch} />
      ) : recipes.length === 0 ? (
        <EmptyState icon="menu_book" title="No recipes yet"
          body="Create a recipe to quickly log meals you eat often." />
      ) : (
        <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
          {recipes.map((r) => (
            <button key={r.id} onClick={() => { setEditing(r); setCreating(false); }}
              className="flex flex-col gap-2 p-4 rounded-[var(--r-card)] text-left transition-colors"
              style={{ background: "var(--surface)" }}>
              <div className="flex items-start justify-between">
                <span className="material-symbols-rounded text-xl" style={{ color: "var(--secondary)" }}>menu_book</span>
                {r.favorite && (
                  <span className="material-symbols-rounded text-lg"
                    style={{ color: "var(--metric-carbs)", fontVariationSettings: "'FILL' 1" }}>star</span>
                )}
              </div>
              <p className="font-bold text-sm">{r.name}</p>
              <p className="text-xs" style={{ color: "var(--muted)" }}>
                {r.ingredients.length} ingredients · {r.servings} serv.
              </p>
            </button>
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
    </div>
  );
}
