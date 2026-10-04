"use client";

import { useEffect, useId, useRef, type KeyboardEvent } from "react";
import { useTranslations } from "next-intl";
import { Button, Icon, KeyHint } from "@/components/ds";
import { TextField } from "@/components/ds/field/TextField";
import { useFormat } from "@/lib/format/useFormat";
import { SEARCH_FILTERS, type ItemUsage, type SearchFilter, type SearchItem } from "../../foodSearch";

export interface FoodSearchPaneProps {
  /** The already-ranked rows (`searchItems`). */
  results: SearchItem[];
  usage: Map<string, ItemUsage>;
  query: string;
  onQueryChange: (q: string) => void;
  filter: SearchFilter;
  onFilterChange: (f: SearchFilter) => void;
  activeKey: string | null;
  onActiveChange: (key: string) => void;
  /** Enter: add the active row with the quantity the preview currently holds. */
  onCommit: () => void;
  /** Tab (and a click on a row): move to the quantity field. */
  onFocusQuantity: () => void;
  /** The empty-result shortcut: create a food with the typed name. */
  onCreate: (name: string) => void;
}

/**
 * The left pane of the add-food dialog (W2.5, client-005): a search field
 * (autofocused, with an `esc` hint), the filter chips Mind · Saját ételek ·
 * Receptek · Kedvencek · Legutóbbiak, "6 TALÁLAT" and the result rows — name,
 * a source line ("Saját · legutóbb ma reggel" / "Recept · 1 adag 412 kcal")
 * and "73 kcal / 100 g", the active row on `--nested` with a 3 px primary bar.
 * Fully keyboard-driven as an ARIA combobox: ↑ ↓ move the active row, Enter
 * adds it, Tab jumps to the quantity.
 */
export function FoodSearchPane({
  results,
  usage,
  query,
  onQueryChange,
  filter,
  onFilterChange,
  activeKey,
  onActiveChange,
  onCommit,
  onFocusQuantity,
  onCreate,
}: FoodSearchPaneProps) {
  const t = useTranslations("nutrition.addFoodModal");
  const fmt = useFormat();
  const listId = useId();
  const rowRefs = useRef(new Map<string, HTMLDivElement>());
  const activeIndex = Math.max(0, results.findIndex((r) => r.key === activeKey));

  // Keep the active row in view while arrowing through a long list.
  useEffect(() => {
    if (activeKey) rowRefs.current.get(activeKey)?.scrollIntoView({ block: "nearest" });
  }, [activeKey]);

  function handleKeyDown(e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault();
      if (results.length === 0) return;
      const next = results[Math.min(results.length - 1, Math.max(0, activeIndex + (e.key === "ArrowDown" ? 1 : -1)))];
      onActiveChange(next.key);
    } else if (e.key === "Enter") {
      e.preventDefault();
      if (results.length > 0) onCommit();
    } else if (e.key === "Tab" && !e.shiftKey && results.length > 0) {
      e.preventDefault();
      onFocusQuantity();
    }
  }

  const sourceLine = (item: SearchItem): string => {
    const u = usage.get(item.key);
    if (item.kind === "recipe") {
      return t("sourceRecipe", { kcal: fmt.integer(item.kcalPerServing) });
    }
    return u ? t("sourceOwnRecent", { when: fmt.relative(new Date(u.lastUsedAt), new Date()) }) : t("sourceOwn");
  };

  return (
    <div className="flex min-h-0 flex-1 flex-col gap-3">
      <div className="relative">
        <TextField
          data-autofocus
          role="combobox"
          aria-expanded
          aria-controls={listId}
          aria-activedescendant={activeKey ? `${listId}-${activeKey}` : undefined}
          aria-label={t("searchLabel")}
          autoComplete="off"
          value={query}
          onChange={(e) => onQueryChange(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder={t("searchPlaceholder")}
          leadingIcon="search"
        />
        {query === "" && <KeyHint className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2">esc</KeyHint>}
      </div>

      <div className="flex flex-wrap gap-2" role="group" aria-label={t("filtersLabel")}>
        {SEARCH_FILTERS.map((f) => {
          const on = f === filter;
          return (
            <button
              key={f}
              type="button"
              aria-pressed={on}
              onClick={() => onFilterChange(f)}
              className="lifey-button type-body-s"
              style={{
                height: 30,
                padding: "0 12px",
                borderRadius: "var(--r-pill)",
                fontWeight: 700,
                background: on ? "var(--primary)" : "var(--nested)",
                color: on ? "var(--on-primary)" : "var(--text-2)",
              }}
            >
              {t(`filter_${f}`)}
            </button>
          );
        })}
      </div>

      <p className="type-section" style={{ color: "var(--text-3)" }} aria-live="polite">
        {t("results", { count: results.length })}
      </p>

      {results.length === 0 ? (
        <div className="flex flex-col items-start gap-3 py-4">
          <p className="type-body-s" style={{ color: "var(--text-2)" }}>
            {query.trim() ? t("noResults") : t("noFoodsYet")}
          </p>
          {query.trim() && (
            <Button variant="tonal" onClick={() => onCreate(query.trim())}>
              <Icon name="add" size={18} />
              {t("createNamed", { name: query.trim() })}
            </Button>
          )}
        </div>
      ) : (
        <div id={listId} role="listbox" aria-label={t("results", { count: results.length })} className="-mx-2 min-h-0 flex-1 overflow-y-auto">
          {results.map((item) => {
            const active = item.key === (results[activeIndex]?.key ?? null);
            const per100 = item.kind === "food" ? item.food.caloriesPer100g : item.kcalPer100g;
            return (
              <div
                key={item.key}
                id={`${listId}-${item.key}`}
                ref={(el) => {
                  if (el) rowRefs.current.set(item.key, el);
                  else rowRefs.current.delete(item.key);
                }}
                role="option"
                aria-selected={active}
                data-active={active}
                onClick={() => {
                  onActiveChange(item.key);
                  onFocusQuantity();
                }}
                className="relative flex cursor-pointer items-center justify-between gap-3 rounded-[var(--r-control)] px-3 py-2.5"
                style={{ background: active ? "var(--nested)" : "transparent" }}
              >
                {active && <span aria-hidden className="absolute left-0 top-2 bottom-2 rounded-full" style={{ width: 3, background: "var(--primary)" }} />}
                <span className="min-w-0">
                  <span className="block" style={{ fontSize: 15, fontWeight: 700, overflowWrap: "anywhere" }}>
                    {item.name}
                  </span>
                  <span className="type-body-s block" style={{ color: "var(--text-3)" }}>
                    {sourceLine(item)}
                  </span>
                </span>
                <span className="tabular shrink-0" style={{ fontSize: 13, fontWeight: 600, color: "var(--text-2)" }}>
                  {t("per100g", { kcal: fmt.integer(per100) })}
                </span>
              </div>
            );
          })}
        </div>
      )}

      <p className="type-body-s" style={{ color: "var(--text-3)" }}>
        {t("keyHint")}
      </p>
    </div>
  );
}
