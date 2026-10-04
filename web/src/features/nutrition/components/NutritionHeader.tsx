"use client";

import type { RefObject } from "react";
import { useTranslations } from "next-intl";
import { Button, Fab, Icon, IconButton, KeyHint, SegmentedControl, Tabs } from "@/components/ds";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import type { NutritionTab } from "../nutritionTab";

export interface NutritionHeaderProps {
  tab: NutritionTab;
  onTabChange: (tab: NutritionTab) => void;
  /** The small numbers after "Ételek" and "Receptek". */
  counts: { foods?: number; recipes?: number };
  copying: boolean;
  onToggleCopy: () => void;
  /** The copy-from-day popover anchors to this. */
  copyAnchor: RefObject<HTMLSpanElement | null>;
  onNewRecipe: () => void;
  onAddFood: () => void;
}

/**
 * The nutrition page's tab row (W2.1, W2.12). From 768 px: underline tabs with their counts and the copy /
 * new-recipe / add-food buttons to the right. On a phone (W2-F, client-079): the three tabs as one full-width
 * segmented control with the copy action as an icon beside it, and the page's one primary action — "＋ Étel",
 * or "＋ Recept" on the recipes tab — as a FAB above the bottom nav, so no row of buttons wraps.
 */
export function NutritionHeader({ tab, onTabChange, counts, copying, onToggleCopy, copyAnchor, onNewRecipe, onAddFood }: NutritionHeaderProps) {
  const t = useTranslations("nutrition");
  const isMobile = useMediaQuery("(max-width: 767px)");

  const items = [
    { value: "meals" as const, label: t("meals") },
    { value: "foods" as const, label: t("foods"), count: counts.foods },
    { value: "recipes" as const, label: t("recipes"), count: counts.recipes },
  ];

  if (isMobile) {
    return (
      <>
        <div className="flex items-center gap-2">
          <div className="min-w-0 flex-1">
            <SegmentedControl<NutritionTab>
              fullWidth
              aria-label={t("tabsAria")}
              options={items.map((i) => ({ value: i.value, label: i.count != null ? `${i.label} ${i.count}` : i.label }))}
              value={tab}
              onChange={onTabChange}
            />
          </div>
          {tab === "meals" && (
            <span ref={copyAnchor} className="inline-flex">
              <IconButton icon="event_repeat" label={t("copyFromDay")} onClick={onToggleCopy} aria-haspopup="dialog" aria-expanded={copying} />
            </span>
          )}
        </div>
        {tab === "recipes" ? (
          <Fab label={t("fabRecipe")} aria-label={t("newRecipe")} onClick={onNewRecipe} />
        ) : (
          <Fab label={t("fabFood")} aria-label={t("addFood")} onClick={onAddFood} />
        )}
      </>
    );
  }

  return (
    <div className="flex flex-wrap items-center justify-between gap-x-4 gap-y-3">
      <div className="min-w-0 flex-1">
        <Tabs<NutritionTab> items={items} value={tab} onChange={onTabChange} aria-label={t("tabsAria")} />
      </div>
      <div className="flex items-center gap-2">
        {tab === "meals" && (
          <span ref={copyAnchor} className="inline-flex">
            <Button variant="secondary" onClick={onToggleCopy} aria-haspopup="dialog" aria-expanded={copying}>
              <Icon name="event_repeat" size={20} />
              {t("copyFromDay")}
            </Button>
          </span>
        )}
        {tab === "recipes" && (
          <Button onClick={onNewRecipe}>
            <Icon name="add" size={20} />
            {t("newRecipe")}
          </Button>
        )}
        <Button variant={tab === "recipes" ? "secondary" : "primary"} onClick={onAddFood}>
          <Icon name="add" size={20} />
          {t("addFood")}
          <KeyHint tone="onPrimary">N</KeyHint>
        </Button>
      </div>
    </div>
  );
}
