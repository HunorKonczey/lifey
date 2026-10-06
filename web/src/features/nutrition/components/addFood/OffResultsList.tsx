"use client";

import { useTranslations } from "next-intl";
import { SectionLabel } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import { isOffSearchable, offSearchNote } from "../../offSearch";
import type { OffSearchItem } from "../../types";
import type { UseOffSearchResult } from "../../useOffSearch";

export interface OffResultsListProps {
  /** What `useOffSearch` says for the typed text. */
  state: UseOffSearchResult;
  /** The text being searched, for the "type 3 letters" hint. */
  query: string;
  /** A row was chosen: the form fills itself from it. */
  onPick: (item: OffSearchItem) => void;
}

/**
 * The OpenFoodFacts results as a plain list of choices (docs/84): "From the OpenFoodFacts database", a row per product — name,
 * the "OFF" tag, the brand, "110 kcal / 100 g" — and exactly one line saying what is going on (searching / nothing found / the
 * English fallback / unavailable / rate-limited / type 3 letters). The food forms use it: picking a row fills the form, the
 * user then checks the values and saves. (The add-food dialog has its own keyboard-driven version inside its search pane.)
 */
export function OffResultsList({ state, query, onPick }: OffResultsListProps) {
  const t = useTranslations("nutrition.addFoodModal");
  const fmt = useFormat();
  const note = offSearchNote(state.response, state.failed);
  const searchable = isOffSearchable(query);

  return (
    <section className="flex flex-col gap-1" data-testid="off-section" aria-label={t("offSection")}>
      <SectionLabel>{t("offSection")}</SectionLabel>
      {!searchable ? (
        <p className="type-body-s py-1" style={{ color: "var(--text-3)" }}>
          {t("offTypeMore")}
        </p>
      ) : (
        <>
          {state.items.length > 0 && (
            <ul className="-mx-2 flex max-h-60 flex-col overflow-y-auto" aria-label={t("offSection")}>
              {state.items.map((row) => (
                <li key={row.key}>
                  <button
                    type="button"
                    onClick={() => onPick(row.off)}
                    className="lifey-button flex w-full items-center justify-between gap-3 rounded-[var(--r-control)] px-2 py-2 text-left"
                    data-testid="off-row"
                  >
                    <span className="min-w-0">
                      <span className="block" style={{ fontSize: 15, fontWeight: 700, overflowWrap: "anywhere" }}>
                        {row.name}
                        <span
                          className="type-label ml-2 align-middle"
                          style={{ background: "var(--control)", color: "var(--text-2)", borderRadius: "var(--r-tag)", padding: "1px 6px" }}
                        >
                          {t("offTag")}
                        </span>
                      </span>
                      <span className="type-body-s block" style={{ color: "var(--text-3)", overflowWrap: "anywhere" }}>
                        {row.off.brand ?? "OpenFoodFacts"}
                      </span>
                    </span>
                    <span className="tabular shrink-0" style={{ fontSize: 13, fontWeight: 600, color: "var(--text-2)" }}>
                      {t("per100g", { kcal: fmt.integer(row.off.caloriesPer100g) })}
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}
          {state.pending && (
            <p className="type-body-s py-1" role="status" style={{ color: "var(--text-3)" }}>
              {t("offSearching")}
            </p>
          )}
          {!state.pending && state.items.length === 0 && !note && (
            <p className="type-body-s py-1" style={{ color: "var(--text-3)" }}>
              {t("offNoResults")}
            </p>
          )}
          {!state.pending && note && (
            <p className="type-body-s py-1" role="note" data-note={note} style={{ color: "var(--text-2)" }}>
              {note === "fellBack" ? t("offFellBack") : note === "rateLimited" ? t("offRateLimited") : t("offUnavailable")}
            </p>
          )}
        </>
      )}
    </section>
  );
}
