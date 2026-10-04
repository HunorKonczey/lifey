"use client";

import type { KeyboardEvent } from "react";
import { useTranslations } from "next-intl";
import { TextField } from "@/components/ds/field/TextField";
import type { MacroDraft } from "../../macroEntry";

export interface MacroEntryFormProps {
  draft: MacroDraft;
  onChange: (draft: MacroDraft) => void;
  /** Enter in any field: add with what is typed. */
  onCommit: () => void;
}

/**
 * The add-food dialog's "Enter macros" mode (the left pane in place of the
 * search): a name, the portion the numbers are for, and calories / protein /
 * carbs / fat. For a meal that is not in the food list — a restaurant lunch.
 * Saving stores it as a hidden food, so it never shows up in the lists.
 */
export function MacroEntryForm({ draft, onChange, onCommit }: MacroEntryFormProps) {
  const t = useTranslations("nutrition.addFoodModal");
  const set = (key: keyof MacroDraft) => (e: { target: { value: string } }) => onChange({ ...draft, [key]: e.target.value });

  function handleKeyDown(e: KeyboardEvent<HTMLDivElement>) {
    if (e.key === "Enter" && e.target instanceof HTMLInputElement) {
      e.preventDefault();
      onCommit();
    }
  }

  return (
    <div className="flex min-h-0 flex-1 flex-col gap-4" onKeyDown={handleKeyDown}>
      <TextField
        data-autofocus
        autoFocus
        autoComplete="off"
        label={t("macroName")}
        placeholder={t("macroNamePlaceholder")}
        value={draft.name}
        onChange={set("name")}
      />
      <TextField
        autoComplete="off"
        inputMode="decimal"
        label={t("macroGrams")}
        hint={t("macroGramsHint")}
        placeholder="100"
        value={draft.grams}
        onChange={set("grams")}
      />
      <div className="grid grid-cols-2 gap-3">
        <TextField autoComplete="off" inputMode="decimal" label={t("macroCalories")} value={draft.calories} onChange={set("calories")} />
        <TextField autoComplete="off" inputMode="decimal" label={t("macroProtein")} value={draft.protein} onChange={set("protein")} />
        <TextField autoComplete="off" inputMode="decimal" label={t("macroCarbs")} value={draft.carbs} onChange={set("carbs")} />
        <TextField autoComplete="off" inputMode="decimal" label={t("macroFat")} value={draft.fat} onChange={set("fat")} />
      </div>
      <p className="type-body-s mt-auto" style={{ color: "var(--text-3)" }}>
        {t("macroKeyHint")}
      </p>
    </div>
  );
}
