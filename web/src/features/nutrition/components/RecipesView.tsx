"use client";

import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { recipeApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useDateStore } from "@/lib/hooks/useDateStore";
import { Skeleton } from "@/components/status/Skeleton";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { RecipeEditor } from "./RecipeEditor";
import { LogRecipeDialog } from "./LogRecipeDialog";
import type { RecipeResponse } from "../types";

const PAGE_SIZE = 200;
const SEARCH_DEBOUNCE_MS = 300;

export function RecipesView() {
  const { date } = useDateStore();
  const [favoritesOnly, setFavoritesOnly] = useState(false);
  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [editing, setEditing] = useState<RecipeResponse | null>(null);
  const [creating, setCreating] = useState(false);
  const [logging, setLogging] = useState<RecipeResponse | null>(null);

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

  const recipes = (data?.content ?? []).filter((r) => !favoritesOnly || r.favorite);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center gap-3">
        <div className="flex items-center gap-2 px-3 h-9 rounded-[var(--r-input)] flex-1 min-w-[180px]"
          style={{ background: "var(--surface)", border: "1px solid var(--outline)" }}>
          <span className="material-symbols-rounded text-base" style={{ color: "var(--muted)" }}>search</span>
          <input
            value={search} onChange={(e) => setSearch(e.target.value)}
            placeholder="Search recipes…"
            className="flex-1 bg-transparent outline-none text-sm"
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
        <EmptyState
          icon="menu_book"
          title={debouncedSearch ? "No recipes match" : "No recipes yet"}
          body={debouncedSearch
            ? "Try a different search term."
            : "Create a recipe to quickly log meals you eat often."}
        />
      ) : (
        <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
          {recipes.map((r) => (
            <div key={r.id}
              className="flex flex-col gap-2 p-4 rounded-[var(--r-card)] text-left"
              style={{ background: "var(--surface)" }}>
              <button onClick={() => { setEditing(r); setCreating(false); }}
                className="flex flex-col gap-2 text-left flex-1">
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
              <button onClick={() => setLogging(r)}
                className="mt-1 flex items-center justify-center gap-1 h-8 rounded-[var(--r-input)] text-xs font-semibold transition-colors"
                style={{ background: "color-mix(in srgb, var(--primary) 15%, transparent)", color: "var(--primary)" }}>
                <span className="material-symbols-rounded text-base">restaurant</span> Log as meal
              </button>
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
    </div>
  );
}
