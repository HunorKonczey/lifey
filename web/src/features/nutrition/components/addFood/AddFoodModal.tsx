"use client";

import { createContext, useContext, useMemo, useRef, useState, type ReactNode } from "react";
import { useQuery } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { Modal } from "@/components/ds/overlay/Modal";
import { SegmentedControl } from "@/components/ds/SegmentedControl";
import { queryKeys } from "@/lib/api/queryKeys";
import { foodApi, mealApi, recipeApi } from "../../api";
import { buildSearchItems, searchItems, usageByKey, type ItemUsage, type SearchFilter, type SearchItem } from "../../foodSearch";
import { EMPTY_MACRO_DRAFT, type MacroDraft } from "../../macroEntry";
import { readOffSearchPreference, writeOffSearchPreference, type ListItem } from "../../offSearch";
import { computeFoodUsage, computeRecipeUsage } from "../../usage";
import { useNoOffSearch, useOffSearchForLocale, type UseOffSearchResult } from "../../useOffSearch";
import { FoodSearchPane } from "./FoodSearchPane";
import { MacroEntryForm } from "./MacroEntryForm";

/** Search the user's foods and recipes, or type the macros of something that is in neither. */
export type AddFoodMode = "search" | "macros";

/** What the right-hand pane gets to work with. */
export interface AddFoodPreviewContext {
  /** The row currently highlighted in the search pane (null when nothing matches) — an own food or recipe, or an OpenFoodFacts result. */
  active: ListItem | null;
  usage: Map<string, ItemUsage>;
  /** Attach to the preview's quantity input (`ref={ctx.registerQuantity}`) — Tab in the search field
   *  and a click on a row then focus it. */
  registerQuantity: (el: HTMLInputElement | null) => void;
  /** The preview tells the dialog what Enter in the search field should do. */
  setCommit: (commit: (() => void) | null) => void;
  /** Back to the search field, keeping the query. */
  focusSearch: () => void;
  mode: AddFoodMode;
  /** What is typed in the "Enter macros" form (only meaningful in that mode). */
  macroDraft: MacroDraft;
  /** After an add the dialog stays open for the next one: clears the search (or the macro form) and refocuses it. */
  reset: () => void;
}

const AddFoodContext = createContext<AddFoodPreviewContext | null>(null);

/** For the right-hand pane: the highlighted row, the usage map and the hooks into the search pane. */
export function useAddFoodContext(): AddFoodPreviewContext {
  const ctx = useContext(AddFoodContext);
  if (!ctx) throw new Error("useAddFoodContext must be used inside <AddFoodModal>");
  return ctx;
}

export interface AddFoodModalViewProps {
  open: boolean;
  onClose: () => void;
  items: SearchItem[];
  usage: Map<string, ItemUsage>;
  /** Start with this typed into the search field. */
  initialQuery?: string;
  /** Start with this row (`food:12`) highlighted. */
  initialKey?: string;
  /** Empty-result shortcut: "Új étel létrehozása «joghurt» néven". */
  onCreate: (name: string) => void;
  /** The right-hand pane (W2.6's preview + submit); reads the dialog through `useAddFoodContext`. */
  children: ReactNode;
  /**
   * OpenFoodFacts search (docs/84): a **hook** that turns the typed text and the checkbox into results. Given, the pane
   * shows the "Search OpenFoodFacts too" checkbox; absent, the dialog is the plain own-foods search. It is called on
   * every render, so it must be the same function every time (a module-level hook, not one made inline).
   */
  useOff?: (args: { query: string; checked: boolean }) => UseOffSearchResult;
  /** Whether the checkbox starts ticked (the device's remembered choice). */
  initialOffChecked?: boolean;
  onOffCheckedChange?: (checked: boolean) => void;
}



/**
 * The add-food dialog's shell (W2.5, client-005): an 880 px `Modal`, a
 * `400px | 1fr` grid, the search pane on the left and whatever the caller
 * renders as the preview on the right. Below 768px the `Modal` itself becomes
 * the bottom sheet (W0.12). Presentational — `AddFoodModal` below wires the data.
 */
export function AddFoodModalView({
  open,
  onClose,
  items,
  usage,
  initialQuery = "",
  initialKey,
  onCreate,
  children,
  useOff,
  initialOffChecked = false,
  onOffCheckedChange,
}: AddFoodModalViewProps) {
  const t = useTranslations("nutrition.addFoodModal");
  const [query, setQuery] = useState(initialQuery);
  const [filter, setFilter] = useState<SearchFilter>("all");
  const [pickedKey, setPickedKey] = useState<string | null>(initialKey ?? null);
  const [mode, setMode] = useState<AddFoodMode>("search");
  const [macroDraft, setMacroDraft] = useState<MacroDraft>(EMPTY_MACRO_DRAFT);
  const [offChecked, setOffChecked] = useState(initialOffChecked);
  const off = (useOff ?? useNoOffSearch)({ query, checked: offChecked && !!useOff });
  const quantityInput = useRef<HTMLInputElement | null>(null);
  const commitRef = useRef<(() => void) | null>(null);
  const searchWrapRef = useRef<HTMLDivElement>(null);

  const results = useMemo(() => searchItems({ items, query, filter, usage }), [items, query, filter, usage]);
  // The highlighted row is the picked one while it is still in a list (own rows, then OpenFoodFacts rows), else the first own row.
  const offRows = offChecked ? off.items : [];
  const active: ListItem | null = results.find((r) => r.key === pickedKey) ?? offRows.find((r) => r.key === pickedKey) ?? results[0] ?? null;

  const ctx: AddFoodPreviewContext = {
    active,
    usage,
    registerQuantity: (el) => {
      quantityInput.current = el;
    },
    setCommit: (commit) => {
      commitRef.current = commit;
    },
    focusSearch: () => searchWrapRef.current?.querySelector("input")?.focus(),
    mode,
    macroDraft,
    reset: () => {
      if (mode === "macros") setMacroDraft(EMPTY_MACRO_DRAFT);
      else {
        setQuery("");
        setPickedKey(null);
      }
      // The field is already mounted in both modes; focus it once the cleared value is rendered.
      queueMicrotask(() => searchWrapRef.current?.querySelector("input")?.focus());
    },
  };

  return (
    <Modal open={open} onClose={onClose} width={880} aria-label={t("title")}>
      <div className="grid md:grid-cols-[400px_minmax(0,1fr)]" style={{ minHeight: 540 }}>
        <div ref={searchWrapRef} className="flex min-h-0 flex-col gap-4 p-5 md:max-h-[85vh]" style={{ borderRight: "1px solid var(--hairline)" }}>
          <h2 className="type-title-l">{t("title")}</h2>
          <SegmentedControl<AddFoodMode>
            aria-label={t("modeLabel")}
            fullWidth
            value={mode}
            onChange={setMode}
            options={[
              { value: "search", label: t("modeSearch"), icon: "search" },
              { value: "macros", label: t("modeMacros"), icon: "edit_note" },
            ]}
          />
          {mode === "search" ? (
            <FoodSearchPane
              results={results}
              usage={usage}
              query={query}
              onQueryChange={setQuery}
              filter={filter}
              onFilterChange={setFilter}
              activeKey={active?.key ?? null}
              onActiveChange={setPickedKey}
              onCommit={() => commitRef.current?.()}
              onFocusQuantity={() => quantityInput.current?.focus()}
              onCreate={onCreate}
              off={
                useOff
                  ? {
                      checked: offChecked,
                      onCheckedChange: (next) => {
                        setOffChecked(next);
                        onOffCheckedChange?.(next);
                      },
                      state: off,
                    }
                  : undefined
              }
            />
          ) : (
            <MacroEntryForm draft={macroDraft} onChange={setMacroDraft} onCommit={() => commitRef.current?.()} />
          )}
        </div>
        <div className="p-6">
          <AddFoodContext.Provider value={ctx}>{children}</AddFoodContext.Provider>
        </div>
      </div>
    </Modal>
  );
}

export type AddFoodModalProps = Omit<AddFoodModalViewProps, "items" | "usage" | "useOff" | "initialOffChecked" | "onOffCheckedChange">;

/**
 * The connected dialog: the user's foods and recipes, and the usage derived from their meals — and the
 * OpenFoodFacts option, remembered per device (docs/84 D10).
 */
export function AddFoodModal(props: AddFoodModalProps) {
  // Mounted only when the dialog opens (never during server rendering), so reading the device's choice here is safe.
  const [offChecked] = useState(readOffSearchPreference);
  const { data: foods } = useQuery({ queryKey: queryKeys.foods.all(), queryFn: foodApi.list, enabled: props.open });
  const { data: recipes } = useQuery({ queryKey: queryKeys.recipes.all(), queryFn: recipeApi.list, enabled: props.open });
  const { data: meals } = useQuery({ queryKey: queryKeys.meals.all(), queryFn: mealApi.list, enabled: props.open });

  const items = useMemo(() => buildSearchItems(foods ?? [], recipes ?? []), [foods, recipes]);
  const usage = useMemo(
    () => usageByKey(computeFoodUsage(meals ?? []), computeRecipeUsage(meals ?? [], recipes ?? [])),
    [meals, recipes],
  );

  return (
    <AddFoodModalView
      {...props}
      items={items}
      usage={usage}
      useOff={useOffSearchForLocale}
      initialOffChecked={offChecked}
      onOffCheckedChange={writeOffSearchPreference}
    />
  );
}
