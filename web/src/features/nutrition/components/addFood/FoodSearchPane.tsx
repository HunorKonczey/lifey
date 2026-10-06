"use client";

import { useEffect, useId, useRef, type KeyboardEvent } from "react";
import { useTranslations } from "next-intl";
import { Button, Checkbox, Icon, KeyHint, SectionLabel } from "@/components/ds";
import { TextField } from "@/components/ds/field/TextField";
import { useFormat } from "@/lib/format/useFormat";
import { SEARCH_FILTERS, type ItemUsage, type SearchFilter, type SearchItem } from "../../foodSearch";
import { isOffSearchable, offSearchNote, type OffItem } from "../../offSearch";
import type { UseOffSearchResult } from "../../useOffSearch";

/** The "Search OpenFoodFacts too" option and what it found (docs/84). Absent: the pane is the plain own-foods search. */
export interface OffSearchPaneProps {
  checked: boolean;
  onCheckedChange: (checked: boolean) => void;
  state: UseOffSearchResult;
}

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
  off?: OffSearchPaneProps;
}

/**
 * The left pane of the add-food dialog (W2.5, client-005): a search field
 * (autofocused, with an `esc` hint), the filter chips Mind · Saját ételek ·
 * Receptek · Kedvencek · Legutóbbiak, "6 TALÁLAT" and the result rows — name,
 * a source line ("Saját · legutóbb ma reggel" / "Recept · 1 adag 412 kcal")
 * and "73 kcal / 100 g", the active row on `--nested` with a 3 px primary bar.
 * Fully keyboard-driven as an ARIA combobox: ↑ ↓ move the active row, Enter
 * adds it, Tab jumps to the quantity.
 *
 * With `off` (docs/84) there is a "Search OpenFoodFacts too" checkbox, and when it is
 * ticked a second section "From OpenFoodFacts" under the own results: its rows are
 * reached by ↓ after the last own row, never ranked among them, and the count above
 * stays the own results' count.
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
  off,
}: FoodSearchPaneProps) {
  const t = useTranslations("nutrition.addFoodModal");
  const fmt = useFormat();
  const listId = useId();
  const offListId = useId();
  const rowRefs = useRef(new Map<string, HTMLDivElement>());
  const searchWrapRef = useRef<HTMLDivElement>(null);

  const offItems = off?.checked ? off.state.items : [];
  // ↑ ↓ walk the own rows and then the OpenFoodFacts rows as one list.
  const navKeys = [...results.map((r) => r.key), ...offItems.map((r) => r.key)];
  const activeIndex = navKeys.indexOf(activeKey ?? "");

  // Keep the active row in view while arrowing through a long list.
  useEffect(() => {
    if (activeKey) rowRefs.current.get(activeKey)?.scrollIntoView({ block: "nearest" });
  }, [activeKey]);

  function handleKeyDown(e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault();
      if (navKeys.length === 0) return;
      // Nothing highlighted yet (no own results): ↓ lands on the first row, not the second.
      const from = activeIndex < 0 ? (e.key === "ArrowDown" ? -1 : 1) : activeIndex;
      onActiveChange(navKeys[Math.min(navKeys.length - 1, Math.max(0, from + (e.key === "ArrowDown" ? 1 : -1)))]);
    } else if (e.key === "Enter") {
      e.preventDefault();
      if (navKeys.length > 0) onCommit();
    } else if (e.key === "Tab" && !e.shiftKey && navKeys.length > 0) {
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

  /** One result row, own or OpenFoodFacts: name (+ a small tag), a second line, and "73 kcal / 100 g". */
  const renderRow = (key: string, name: string, secondLine: string, per100: number, tag?: string) => {
    const active = key === activeKey;
    return (
      <div
        key={key}
        id={`${listId}-${key}`}
        ref={(el) => {
          if (el) rowRefs.current.set(key, el);
          else rowRefs.current.delete(key);
        }}
        role="option"
        aria-selected={active}
        data-active={active}
        onClick={() => {
          onActiveChange(key);
          onFocusQuantity();
        }}
        className="relative flex cursor-pointer items-center justify-between gap-3 rounded-[var(--r-control)] px-3 py-2.5"
        style={{ background: active ? "var(--nested)" : "transparent" }}
      >
        {active && <span aria-hidden className="absolute left-0 top-2 bottom-2 rounded-full" style={{ width: 3, background: "var(--primary)" }} />}
        <span className="min-w-0">
          <span className="block" style={{ fontSize: 15, fontWeight: 700, overflowWrap: "anywhere" }}>
            {name}
            {tag && (
              <span
                className="type-label ml-2 align-middle"
                style={{ background: "var(--control)", color: "var(--text-2)", borderRadius: "var(--r-tag)", padding: "1px 6px" }}
              >
                {tag}
              </span>
            )}
          </span>
          <span className="type-body-s block" style={{ color: "var(--text-3)", overflowWrap: "anywhere" }}>
            {secondLine}
          </span>
        </span>
        <span className="tabular shrink-0" style={{ fontSize: 13, fontWeight: 600, color: "var(--text-2)" }}>
          {t("per100g", { kcal: fmt.integer(per100) })}
        </span>
      </div>
    );
  };

  const offRow = (item: OffItem) =>
    renderRow(item.key, item.name, item.off.brand ?? "OpenFoodFacts", item.off.caloriesPer100g, t("offTag"));

  // ── the OpenFoodFacts section ──
  const offState = off?.state;
  const offNote = offState ? offSearchNote(offState.response, offState.failed) : null;
  const typedSearchable = isOffSearchable(query);
  const showOffSection = !!off?.checked && query.trim() !== "";

  return (
    <div className="flex min-h-0 flex-1 flex-col gap-3">
      <div ref={searchWrapRef} className="relative">
        <TextField
          data-autofocus
          role="combobox"
          aria-expanded
          aria-controls={off?.checked ? `${listId} ${offListId}` : listId}
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

      {off && (
        <Checkbox
          checked={off.checked}
          onChange={(next) => {
            off.onCheckedChange(next);
            // Back to the search field: the next thing a person does after ticking is keep typing.
            searchWrapRef.current?.querySelector("input")?.focus();
          }}
          label={t("offLabel")}
        />
      )}
      {off?.checked && (
        <p className="type-body-s" data-testid="off-hint" style={{ color: "var(--text-3)" }}>
          {t("offHint")}
        </p>
      )}

      <p className="type-section" style={{ color: "var(--text-3)" }} aria-live="polite">
        {t("results", { count: results.length })}
      </p>

      {/* One scroll area for both lists, so arrowing from the last own row into OpenFoodFacts keeps the active row in view. */}
      <div className="-mx-2 min-h-0 flex-1 overflow-y-auto">
        {results.length === 0 ? (
          <div className="flex flex-col items-start gap-3 px-2 py-4">
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
          <div id={listId} role="listbox" aria-label={t("results", { count: results.length })}>
            {results.map((item) =>
              renderRow(item.key, item.name, sourceLine(item), item.kind === "food" ? item.food.caloriesPer100g : item.kcalPer100g),
            )}
          </div>
        )}

        {showOffSection && offState && (
          <section className="mt-3 flex flex-col gap-1 px-2" data-testid="off-section" aria-label={t("offSection")}>
            <SectionLabel>{t("offSection")}</SectionLabel>
            {!typedSearchable ? (
              <p className="type-body-s py-2" style={{ color: "var(--text-3)" }}>
                {t("offTypeMore")}
              </p>
            ) : (
              <>
                {offItems.length > 0 && (
                  <div id={offListId} role="listbox" aria-label={t("offSection")} className="-mx-2">
                    {offItems.map(offRow)}
                  </div>
                )}
                {offState.pending && (
                  <p className="type-body-s py-2" role="status" style={{ color: "var(--text-3)" }}>
                    {t("offSearching")}
                  </p>
                )}
                {!offState.pending && offItems.length === 0 && !offNote && (
                  <p className="type-body-s py-2" style={{ color: "var(--text-3)" }}>
                    {t("offNoResults")}
                  </p>
                )}
                {!offState.pending && offNote && (
                  <p className="type-body-s py-2" role="note" data-note={offNote} style={{ color: "var(--text-2)" }}>
                    {offNote === "fellBack" ? t("offFellBack") : offNote === "rateLimited" ? t("offRateLimited") : t("offUnavailable")}
                  </p>
                )}
              </>
            )}
          </section>
        )}
      </div>

      <p className="type-body-s" style={{ color: "var(--text-3)" }}>
        {t("keyHint")}
      </p>
    </div>
  );
}
