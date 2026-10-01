"use client";

import { useEffect, useRef, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { format } from "date-fns";
import { Button, NumberField } from "@/components/ds";
import { Drawer } from "@/components/ds/overlay/Drawer";
import { useFormat } from "@/lib/format/useFormat";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { stepsApi } from "../api";
import type { DailyStepCountResponse } from "../types";

/**
 * The small drawer the hero's "Szerkesztés" opens (W4.6): one number for the selected day — create when the day has no
 * count yet, update when it has. Enter saves; Esc / scrim / × ask first when the number was changed.
 */
export function EditStepsDrawer({
  date,
  entry,
  onClose,
}: {
  date: Date;
  entry: DailyStepCountResponse | null;
  onClose: () => void;
}) {
  const t = useTranslations("steps");
  const common = useTranslations("common");
  const fmt = useFormat();
  const queryClient = useQueryClient();
  const { show } = useToast();
  const start = entry?.steps ?? 0;
  const [steps, setSteps] = useState(start);
  const dateStr = format(date, "yyyy-MM-dd");
  // The drawer's focus trap lands on its close button first; move focus to the number once it has settled.
  const input = useRef<HTMLInputElement>(null);
  useEffect(() => {
    const id = requestAnimationFrame(() => input.current?.focus());
    return () => cancelAnimationFrame(id);
  }, []);

  const saveMutation = useMutation({
    mutationFn: (count: number) => (entry ? stepsApi.update(entry.id, { date: dateStr, steps: count }) : stepsApi.create({ date: dateStr, steps: count })),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.steps.all() });
      show(t("saved"), "success");
      onClose();
    },
    onError: () => show(t("saveFailed"), "error"),
  });

  const save = (count: number = steps) => {
    if (!saveMutation.isPending) saveMutation.mutate(Math.max(0, Math.round(count)));
  };

  return (
    <Drawer
      open
      onClose={onClose}
      width={480}
      title={t("editTitle")}
      isDirty={steps !== start}
      footer={
        <Button className="w-full" onClick={() => save()} disabled={saveMutation.isPending}>
          {saveMutation.isPending ? common("saving") : common("save")}
        </Button>
      }
    >
      <div className="flex flex-col gap-4 py-2">
        <p className="type-body-s" style={{ color: "var(--text-2)" }}>
          {fmt.longDate(date)}
        </p>
        <NumberField
          label={t("stepsLabel")}
          value={steps}
          onChange={setSteps}
          step={100}
          min={0}
          max={200000}
          maxDecimals={0}
          selectOnFocus
          onEnter={(v) => save(v)}
          inputRef={input}
        />
      </div>
    </Drawer>
  );
}
