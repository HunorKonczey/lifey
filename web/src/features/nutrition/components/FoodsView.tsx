"use client";

import { useEffect, useState } from "react";
import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { foodApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { DataTable, type Column } from "@/components/data/DataTable";
import { Skeleton } from "@/components/status/Skeleton";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { FoodEditor } from "./FoodEditor";
import type { FoodResponse } from "../types";
import type { FoodFormValues } from "../schemas";

const PAGE_SIZE = 25;
const SEARCH_DEBOUNCE_MS = 300;

// Maps DataTable column keys to the backend's sortable JPA property names —
// they diverge for the metric columns (short UI labels vs. entity fields).
const SORT_FIELDS: Record<string, string> = {
  name: "name",
  kcal: "caloriesPer100g",
  protein: "proteinPer100g",
  carbs: "carbsPer100g",
  fat: "fatPer100g",
};

export function FoodsView() {
  const { show } = useToast();
  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [page, setPage] = useState(0);
  const [sortKey, setSortKey] = useState<string | null>(null);
  const [sortDir, setSortDir] = useState<"asc" | "desc">("asc");
  const [barcode, setBarcode] = useState("");
  const [barcodeLoading, setBarcodeLoading] = useState(false);
  const [selected, setSelected] = useState<FoodResponse | null>(null);
  const [creating, setCreating] = useState(false);
  const [prefill, setPrefill] = useState<(Partial<FoodFormValues> & { barcode?: string }) | undefined>();

  // Debounce the search box so typing doesn't refetch on every keystroke.
  // Reset to page 0 alongside it, since a new search term invalidates the
  // current page position.
  useEffect(() => {
    const timeout = setTimeout(() => {
      setDebouncedSearch(search.trim());
      setPage(0);
    }, SEARCH_DEBOUNCE_MS);
    return () => clearTimeout(timeout);
  }, [search]);

  const sort = sortKey ? `${SORT_FIELDS[sortKey] ?? sortKey},${sortDir}` : undefined;
  const pageParams = { page, size: PAGE_SIZE, search: debouncedSearch || undefined, sort };

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.foods.page(pageParams),
    queryFn: () => foodApi.page(pageParams),
    placeholderData: keepPreviousData,
  });

  const foods = data?.content ?? [];

  const handleBarcode = async () => {
    if (!barcode.trim()) return;
    setBarcodeLoading(true);
    try {
      const res = await foodApi.barcode(barcode.trim());
      if (res.source === "LOCAL" && res.id != null) {
        // Fetch directly rather than searching the current (server-paged)
        // `foods` page — the matching food may live on a different page.
        const existing = foods.find((f) => f.id === res.id) ?? (await foodApi.get(res.id));
        setSelected(existing);
        setCreating(false);
        show("Found in your catalog", "success");
      } else {
        // OPENFOODFACTS — prefill new-food editor
        setSelected(null);
        setPrefill({
          name: res.name,
          caloriesPer100g: res.caloriesPer100g,
          proteinPer100g: res.proteinPer100g,
          carbsPer100g: res.carbsPer100g ?? 0,
          fatPer100g: res.fatPer100g ?? 0,
          barcode: res.barcode,
        });
        setCreating(true);
        show("Loaded from OpenFoodFacts — review and save", "success");
      }
      setBarcode("");
    } catch {
      show("Barcode not found", "warning");
    } finally {
      setBarcodeLoading(false);
    }
  };

  const columns: Column<FoodResponse>[] = [
    {
      key: "name", header: "Name", sortable: true,
      sortValue: (f) => f.name.toLowerCase(),
      render: (f) => (
        <span className="font-semibold" style={{ color: "var(--on-surface)" }}>
          {f.name}
          {f.hidden && (
            <span className="material-symbols-rounded text-sm ml-1 align-middle" style={{ color: "var(--muted)" }}>
              visibility_off
            </span>
          )}
        </span>
      ),
    },
    {
      key: "kcal", header: "Kcal", sortable: true, align: "right", color: "var(--metric-kcal)",
      sortValue: (f) => f.caloriesPer100g,
      render: (f) => Math.round(f.caloriesPer100g),
    },
    {
      key: "protein", header: "Protein", sortable: true, align: "right", color: "var(--metric-protein)",
      sortValue: (f) => f.proteinPer100g,
      render: (f) => `${+f.proteinPer100g.toFixed(1)}g`,
    },
    {
      key: "carbs", header: "Carbs", sortable: true, align: "right", color: "var(--metric-carbs)",
      sortValue: (f) => f.carbsPer100g ?? 0,
      render: (f) => (f.carbsPer100g != null ? `${+f.carbsPer100g.toFixed(1)}g` : "—"),
    },
    {
      key: "fat", header: "Fat", sortable: true, align: "right", color: "var(--metric-fat)",
      sortValue: (f) => f.fatPer100g ?? 0,
      render: (f) => (f.fatPer100g != null ? `${+f.fatPer100g.toFixed(1)}g` : "—"),
    },
  ];

  const showEditor = creating || selected !== null;

  return (
    <div className="flex gap-6">
      <div className="flex-1 min-w-0 flex flex-col gap-4">
        {/* Toolbar */}
        <div className="flex flex-wrap items-center gap-3">
          <div className="flex items-center gap-2 px-3 h-10 rounded-[var(--r-input)] flex-1 min-w-[180px]"
            style={{ background: "var(--surface)", border: "1px solid var(--outline)" }}>
            <span className="material-symbols-rounded text-base" style={{ color: "var(--muted)" }}>search</span>
            <input
              value={search} onChange={(e) => setSearch(e.target.value)}
              placeholder="Search foods…"
              className="flex-1 bg-transparent outline-none text-sm"
            />
          </div>

          <div className="flex items-center gap-2 px-3 h-10 rounded-[var(--r-input)] min-w-[200px]"
            style={{ background: "var(--surface)", border: "1px solid var(--outline)" }}>
            <span className="material-symbols-rounded text-base" style={{ color: "var(--muted)" }}>barcode_scanner</span>
            <input
              value={barcode} onChange={(e) => setBarcode(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && handleBarcode()}
              placeholder="Barcode…"
              className="flex-1 bg-transparent outline-none text-sm tabular"
            />
            <button onClick={handleBarcode} disabled={barcodeLoading}
              className="text-xs font-semibold disabled:opacity-50" style={{ color: "var(--primary)" }}>
              {barcodeLoading ? "…" : "Look up"}
            </button>
          </div>

          <button
            onClick={() => { setCreating(true); setSelected(null); setPrefill(undefined); }}
            className="flex items-center gap-1 px-4 h-10 rounded-[var(--r-input)] font-semibold text-sm"
            style={{ background: "var(--primary)", color: "#1E1F18" }}
          >
            <span className="material-symbols-rounded text-lg">add</span> New food
          </button>
        </div>

        {/* Table */}
        {isLoading ? (
          <Skeleton variant="table" />
        ) : isError ? (
          <ErrorState onRetry={refetch} />
        ) : foods.length === 0 ? (
          <EmptyState
            icon="nutrition"
            title={debouncedSearch ? "No foods match" : "No foods yet"}
            body={debouncedSearch
              ? "Try a different search term."
              : "Add a food manually or scan a barcode to get started."}
          />
        ) : (
          <DataTable
            columns={columns}
            rows={foods}
            rowKey={(f) => f.id}
            selectedKey={selected?.id ?? null}
            onRowClick={(f) => { setSelected(f); setCreating(false); }}
            pageSize={PAGE_SIZE}
            serverPagination={{
              page,
              totalPages: data?.totalPages ?? 1,
              totalElements: data?.totalElements,
              onPageChange: setPage,
              sortKey,
              sortDir,
              onSortChange: (key) => {
                if (sortKey === key) {
                  setSortDir((d) => (d === "asc" ? "desc" : "asc"));
                } else {
                  setSortKey(key);
                  setSortDir("asc");
                }
                setPage(0);
              },
            }}
          />
        )}
      </div>

      {/* Editor panel */}
      {showEditor && (
        <div className="w-[340px] shrink-0">
          <FoodEditor
            food={selected}
            prefill={creating ? prefill : undefined}
            onSaved={() => { setSelected(null); setCreating(false); setPrefill(undefined); }}
            onCancel={() => { setSelected(null); setCreating(false); setPrefill(undefined); }}
          />
        </div>
      )}
    </div>
  );
}
