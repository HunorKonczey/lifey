"use client";

import { useMemo } from "react";
import { useLocale } from "next-intl";
import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { queryKeys } from "@/lib/api/queryKeys";
import { useDebouncedValue } from "@/lib/hooks/useDebouncedValue";
import { foodApi } from "./api";
import {
  OFF_SEARCH_DEBOUNCE_MS,
  OFF_SEARCH_STALE_MS,
  isOffSearchable,
  offItemToSearchItem,
  offSearchEnabled,
  offSearchLang,
  sanitizeOffQuery,
  type OffItem,
} from "./offSearch";
import type { OffSearchLang, OffSearchResponse } from "./types";

export interface UseOffSearchResult {
  /** A request is being made or its result shown: the option is ticked and enough is typed. */
  active: boolean;
  /** Waiting for OpenFoodFacts (or for the typing to settle): show a skeleton line, not a spinner over the list. */
  pending: boolean;
  /** The result rows; empty when inactive, still loading the first time, or nothing matched. */
  items: OffItem[];
  /** The answer, `undefined` when inactive or not yet arrived. The previous answer stays while the next one loads. */
  response: OffSearchResponse | undefined;
  /** The request itself failed (network): to be shown like `UNAVAILABLE`. */
  failed: boolean;
}

/**
 * OpenFoodFacts results for the add-food dialog (docs/84 D10). Nothing is requested unless `checked`; the typed
 * text is cleaned, debounced and needs 3+ letters or digits; the same search again within ten minutes comes from
 * the cache; a newer keystroke cancels the request in flight. The previous answer is kept while the next one
 * loads, so the list does not flash empty on every letter.
 */
export function useOffSearch({ query, lang, checked }: { query: string; lang: OffSearchLang; checked: boolean }): UseOffSearchResult {
  const typed = sanitizeOffQuery(query);
  const settled = useDebouncedValue(typed, OFF_SEARCH_DEBOUNCE_MS);
  const active = offSearchEnabled(checked, typed, settled);

  const { data, isFetching, isError } = useQuery({
    queryKey: queryKeys.offSearch(lang, settled),
    queryFn: ({ signal }) => foodApi.offSearch(settled, lang, signal),
    enabled: active,
    staleTime: OFF_SEARCH_STALE_MS,
    placeholderData: keepPreviousData,
    retry: false,
  });

  const response = active ? data : undefined;
  const items = useMemo(() => (response ? response.items.map(offItemToSearchItem) : []), [response]);
  // Pending is also the short wait while the typing settles: the request for these letters has not started yet.
  const settling = checked && isOffSearchable(typed) && typed !== settled;
  const pending = settling || (active && isFetching);

  return { active, pending, items, response, failed: active && isError };
}

/**
 * `useOffSearch` for the app's UI language (Hungarian searches Hungarian, everything else English). One stable module-level
 * function, so it can be handed to a component as its `useOff` prop (add-food dialog, food editor).
 */
export function useOffSearchForLocale(args: { query: string; checked: boolean }): UseOffSearchResult {
  return useOffSearch({ ...args, lang: offSearchLang(useLocale()) });
}
