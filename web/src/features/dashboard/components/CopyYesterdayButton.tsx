"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { Button, Icon } from "@/components/ds";
import { mealApi } from "@/features/nutrition/api";
import { copyMealPayload, suggestCopy } from "@/features/nutrition/copyMeal";
import type { MealResponse } from "@/features/nutrition/types";
import { queryKeys } from "@/lib/api/queryKeys";
import { useFormat } from "@/lib/format/useFormat";
import { useToast } from "@/lib/hooks/useToast";

/**
 * "Copy yesterday's dinner" (W1.3): one click re-creates yesterday's meal of
 * the type the clock points at (`suggestCopy`) on today, then offers Undo.
 * Hidden unless there is something sensible to copy — and unless the
 * dashboard is on today, since "yesterday" means the day before *now*.
 *
 * Undo here deletes the meal that was just created, so it rides on the toast
 * store's `showUndo` directly: `useUndoableDelete` is the opposite direction
 * (an already-existing item whose DELETE is deferred until the window ends).
 */
export function CopyYesterdayButton({ meals, isToday }: { meals: MealResponse[]; isToday: boolean }) {
  const t = useTranslations("dashboard");
  const fmt = useFormat();
  const queryClient = useQueryClient();

  const suggestion = isToday ? suggestCopy(meals, new Date()) : null;

  const copy = useMutation({
    mutationFn: (source: MealResponse) => mealApi.create(copyMealPayload(source, new Date())),
    onSuccess: (created, source) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.meals.all() });
      const meal = fmt.mealTypeLabel(source.mealType).toLocaleLowerCase(fmt.locale);
      useToast.getState().showUndo(
        t("copyYesterdayDone", { meal }),
        () => {
          mealApi
            .delete(created.id)
            .catch(() => useToast.getState().show(t("copyYesterdayFailed"), "error"))
            .finally(() => queryClient.invalidateQueries({ queryKey: queryKeys.meals.all() }));
        },
        () => {},
      );
    },
    onError: () => useToast.getState().show(t("copyYesterdayFailed"), "error"),
  });

  if (!suggestion) return null;
  const label = t("copyYesterday", { meal: fmt.mealTypeLabel(suggestion.mealType).toLocaleLowerCase(fmt.locale) });

  return (
    <Button
      variant="secondary"
      onClick={() => copy.mutate(suggestion.source)}
      disabled={copy.isPending}
      aria-label={label}
      className="max-sm:px-3!"
    >
      <Icon name="content_copy" size={20} />
      <span className="hidden sm:inline">{label}</span>
    </Button>
  );
}
