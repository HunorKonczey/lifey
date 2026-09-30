"use client";

import { useEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { Button, Card, Icon, IconButton, NumberField, ReadOnlyField, TextField } from "@/components/ds";
import { EMPTY_FOOD, FOOD_DECIMALS, fieldsFromFood, foodRequest, isFoodDirty, type FoodFields } from "../foodEdit";
import { macroCheck } from "../macroCheck";
import type { FoodRequest, FoodResponse } from "../types";

export interface FoodEditorProps {
  /** The food being edited; null = a new one. The caller remounts the editor (`key`) to switch food. */
  food: FoodResponse | null;
  /** Values a new food starts with (a barcode lookup, the add-food dialog's "create “yoghurt”"). */
  prefill?: Partial<FoodResponse>;
  pending?: boolean;
  /** A server-side complaint about the name ("already exists"); shown until the name is edited. */
  nameError?: string;
  onNameEdit?: () => void;
  onSave: (request: FoodRequest) => void;
  onCancel: () => void;
  /** Barcode lookup, offered for a new food only. */
  onLookupBarcode?: (barcode: string) => void;
  lookupPending?: boolean;
  /** Just the form — no card, title or close button — for a container that supplies its own (the drawer below 1280). */
  bare?: boolean;
  /** Tells the container whether there are unsaved changes (the drawer's discard guard). */
  onDirtyChange?: (dirty: boolean) => void;
}

/**
 * The foods tab's editor panel (W2.10, extra-005/006): name, the fixed 100 g basis, kcal and the three
 * macros, an optional barcode, and a live line when the macros don't add up to the kcal — an info note for a
 * small gap, a warning above 10 % (it never blocks saving). "Mentés" stays disabled until something really
 * changed (see `isFoodDirty`).
 */
export function FoodEditor({ food, prefill, pending, nameError, onNameEdit, onSave, onCancel, onLookupBarcode, lookupPending, bare, onDirtyChange }: FoodEditorProps) {
  const t = useTranslations("nutrition.foodEditor");
  const fv = useTranslations("nutrition.foodsView");
  const common = useTranslations("common");
  const formRef = useRef<HTMLFormElement>(null);

  const baseline: FoodFields = food ? fieldsFromFood(food) : EMPTY_FOOD;
  const [fields, setFields] = useState<FoodFields>(() => fieldsFromFood(food, prefill));
  const [triedSave, setTriedSave] = useState(false);
  const set = <K extends keyof FoodFields>(key: K, value: FoodFields[K]) => setFields((f) => ({ ...f, [key]: value }));

  const nameMissing = fields.name.trim() === "";
  const dirty = isFoodDirty(fields, baseline);
  const check = macroCheck(fields);
  useEffect(() => onDirtyChange?.(dirty), [dirty, onDirtyChange]);
  const submit = () => {
    if (nameMissing) {
      setTriedSave(true);
      return;
    }
    onSave(foodRequest(fields, baseline, food?.hidden ?? false));
  };
  // Enter inside a number field commits it first (NumberField does that on Enter), then saves a frame later with the new value.
  const submitSoon = () => requestAnimationFrame(() => formRef.current?.requestSubmit());

  const macroField = (key: "kcal" | "protein" | "carbs" | "fat", label: string, unit: string) => (
    <NumberField
      label={label}
      size="dense"
      unit={unit}
      value={fields[key]}
      onChange={(v) => set(key, v)}
      min={0}
      step={key === "kcal" ? 10 : 0.5}
      maxDecimals={FOOD_DECIMALS}
      selectOnFocus
      // Live, so the macro line below appears while typing — not on blur, where it would shift "Mentés" away mid-click.
      liveUpdate
      onEnter={submitSoon}
    />
  );

  const Shell = bare ? "div" : Card;
  return (
    <Shell className="flex flex-col gap-4" data-testid="food-editor">
      {!bare && (
        <div className="flex items-center justify-between gap-2">
          <h3 style={{ fontSize: 16, fontWeight: 800 }}>{food ? t("editFood") : t("newFood")}</h3>
          <IconButton icon="close" label={t("closeAria")} onClick={onCancel} />
        </div>
      )}

      <form
        ref={formRef}
        noValidate
        onSubmit={(e) => {
          e.preventDefault();
          submit();
        }}
        className="flex flex-col gap-4"
      >
        <TextField
          label={t("name")}
          size="dense"
          value={fields.name}
          onChange={(e) => {
            set("name", e.target.value);
            onNameEdit?.();
          }}
          error={nameError ?? (triedSave && nameMissing ? t("nameRequired") : undefined)}
          autoFocus={!food}
          required
        />

        <ReadOnlyField label={t("basis")} value={t("basisValue")} />

        <div className="grid grid-cols-2 gap-3">
          {macroField("kcal", t("caloriesPer100g"), "kcal")}
          {macroField("protein", t("proteinPer100g"), "g")}
          {macroField("carbs", t("carbsPer100g"), "g")}
          {macroField("fat", t("fatPer100g"), "g")}
        </div>

        {check.tone !== "ok" && (
          <p
            role="status"
            data-testid="macro-line"
            data-tone={check.tone}
            className="type-body-s flex items-start gap-2"
            style={{ color: check.tone === "warning" ? "var(--heart)" : "var(--text-2)" }}
          >
            <Icon name={check.tone === "warning" ? "warning" : "info"} size={18} className="mt-px shrink-0" />
            <span>{t("macroLine", { computed: check.computedKcal, diff: check.diffKcal })}</span>
          </p>
        )}

        <div className="flex items-end gap-2">
          <TextField
            label={t("barcodeOptional")}
            size="dense"
            className="flex-1"
            inputMode="numeric"
            value={fields.barcode}
            onChange={(e) => set("barcode", e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && onLookupBarcode && fields.barcode.trim()) {
                e.preventDefault();
                onLookupBarcode(fields.barcode.trim());
              }
            }}
          />
          {onLookupBarcode && !food && (
            <Button
              variant="secondary"
              onClick={() => onLookupBarcode(fields.barcode.trim())}
              disabled={lookupPending || fields.barcode.trim() === ""}
            >
              {lookupPending ? "…" : fv("lookUp")}
            </Button>
          )}
        </div>

        <div className="flex gap-3">
          <Button variant="secondary" onClick={onCancel} className="flex-1">
            {common("cancel")}
          </Button>
          <Button type="submit" disabled={pending || !dirty} className="flex-1">
            {pending ? common("saving") : common("save")}
          </Button>
        </div>
      </form>
    </Shell>
  );
}
