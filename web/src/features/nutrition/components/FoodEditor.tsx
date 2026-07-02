"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useEffect } from "react";
import { useTranslations } from "next-intl";
import { foodApi } from "../api";
import { foodSchema, type FoodFormValues } from "../schemas";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import type { FoodResponse } from "../types";

interface FoodEditorProps {
  food: FoodResponse | null; // null = new food
  prefill?: Partial<FoodFormValues> & { barcode?: string };
  onSaved: () => void;
  onCancel: () => void;
}

export function FoodEditor({ food, prefill, onSaved, onCancel }: FoodEditorProps) {
  const t = useTranslations("nutrition.foodEditor");
  const common = useTranslations("common");
  const queryClient = useQueryClient();
  const { show } = useToast();

  const MACRO_FIELDS = [
    { name: "caloriesPer100g" as const, label: t("caloriesPer100g"), color: "var(--metric-kcal)" },
    { name: "proteinPer100g" as const, label: t("proteinPer100g"), color: "var(--metric-protein)" },
    { name: "carbsPer100g" as const, label: t("carbsPer100g"), color: "var(--metric-carbs)" },
    { name: "fatPer100g" as const, label: t("fatPer100g"), color: "var(--metric-fat)" },
  ];

  const { register, handleSubmit, reset, watch, setValue, formState: { errors } } =
    useForm<FoodFormValues>({
      resolver: zodResolver(foodSchema),
      defaultValues: {
        name: "", caloriesPer100g: 0, proteinPer100g: 0,
        carbsPer100g: 0, fatPer100g: 0, barcode: null, hidden: false,
      },
    });

  useEffect(() => {
    if (food) {
      reset({
        name: food.name,
        caloriesPer100g: food.caloriesPer100g,
        proteinPer100g: food.proteinPer100g,
        carbsPer100g: food.carbsPer100g ?? 0,
        fatPer100g: food.fatPer100g ?? 0,
        barcode: food.barcode,
        hidden: food.hidden,
      });
    } else if (prefill) {
      reset({
        name: prefill.name ?? "",
        caloriesPer100g: prefill.caloriesPer100g ?? 0,
        proteinPer100g: prefill.proteinPer100g ?? 0,
        carbsPer100g: prefill.carbsPer100g ?? 0,
        fatPer100g: prefill.fatPer100g ?? 0,
        barcode: prefill.barcode ?? null,
        hidden: false,
      });
    } else {
      reset({
        name: "", caloriesPer100g: 0, proteinPer100g: 0,
        carbsPer100g: 0, fatPer100g: 0, barcode: null, hidden: false,
      });
    }
  }, [food, prefill, reset]);

  const mutation = useMutation({
    mutationFn: (values: FoodFormValues) =>
      food ? foodApi.update(food.id, values) : foodApi.create(values),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.foods.all() });
      show(food ? t("updated") : t("created"), "success");
      onSaved();
    },
    onError: () => show(t("saveFailed"), "error"),
  });

  const deleteMutation = useMutation({
    mutationFn: () => foodApi.delete(food!.id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.foods.all() });
      show(t("deleted"), "success");
      onSaved();
    },
    onError: () => show(t("deleteFailed"), "error"),
  });

  const hidden = watch("hidden");

  return (
    <form
      onSubmit={handleSubmit((v) => mutation.mutate(v))}
      className="flex flex-col gap-4 p-5 rounded-[var(--r-card)]"
      style={{ background: "var(--surface)" }}
    >
      <div className="flex items-center justify-between">
        <h3 className="font-bold text-base">{food ? t("editFood") : t("newFood")}</h3>
        <button type="button" onClick={onCancel} aria-label={common("close")}
          className="p-1 rounded-[var(--r-sm)] transition-colors hover:bg-surface-container"
          style={{ color: "var(--on-surface-variant)" }}>
          <span className="material-symbols-rounded">close</span>
        </button>
      </div>

      <div className="flex flex-col gap-1">
        <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>{t("name")}</label>
        <input
          {...register("name")}
          className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm"
          style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}
        />
        {errors.name && <p className="text-xs" style={{ color: "var(--error)" }}>{errors.name.message}</p>}
      </div>

      <div className="grid grid-cols-2 gap-3">
        {MACRO_FIELDS.map(({ name, label, color }) => (
          <div key={name} className="flex flex-col gap-1">
            <label className="text-xs font-semibold" style={{ color }}>{label}</label>
            <input
              {...register(name, { valueAsNumber: true })}
              type="number" step="0.1"
              className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm tabular"
              style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}
            />
            {errors[name] && <p className="text-xs" style={{ color: "var(--error)" }}>{errors[name]?.message}</p>}
          </div>
        ))}
      </div>

      <div className="flex flex-col gap-1">
        <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>{t("barcodeOptional")}</label>
        <input
          {...register("barcode")}
          className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm tabular"
          style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}
        />
      </div>

      {/* Hidden toggle */}
      <button
        type="button"
        onClick={() => setValue("hidden", !hidden)}
        className="flex items-center justify-between px-1"
      >
        <span className="text-sm font-semibold">{t("hiddenFromSearch")}</span>
        <span
          className="relative w-10 h-6 rounded-[var(--r-pill)] transition-colors"
          style={{ background: hidden ? "var(--primary)" : "var(--surface-highest)" }}
        >
          <span
            className="absolute top-0.5 w-5 h-5 rounded-full bg-white transition-all"
            style={{ left: hidden ? 18 : 2 }}
          />
        </span>
      </button>

      <div className="flex gap-2 mt-1">
        <button
          type="submit"
          disabled={mutation.isPending}
          className="flex-1 h-10 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-60"
          style={{ background: "var(--primary)", color: "#1E1F18" }}
        >
          {mutation.isPending ? common("saving") : common("save")}
        </button>
        {food && (
          <button
            type="button"
            onClick={() => deleteMutation.mutate()}
            disabled={deleteMutation.isPending}
            className="px-4 h-10 rounded-[var(--r-input)] font-semibold text-sm transition-colors"
            style={{ background: "color-mix(in srgb, var(--error) 15%, transparent)", color: "var(--error)" }}
            aria-label={t("deleteAria")}
          >
            <span className="material-symbols-rounded text-xl">delete</span>
          </button>
        )}
      </div>
    </form>
  );
}
