"use client";

import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { format } from "date-fns";
import { Button, ConfirmModal, TextField } from "@/components/ds";
import { CalendarPopover } from "@/components/ds/date/CalendarPopover";
import { DateButton } from "@/components/ds/date/DateButton";
import { Drawer } from "@/components/ds/overlay/Drawer";
import { useFormat } from "@/lib/format/useFormat";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { weightApi } from "../api";
import { initialWeight, planWeightSave, type WeightSavePlan } from "../logWeight";
import { parseLocalDate } from "../trend";
import { WEIGHT_NOTE_MAX, type WeightResponse } from "../types";
import { WeightStepper } from "./WeightStepper";

/**
 * "Súly rögzítése" (W4.4, W4-A, client-020): a drawer with the weight as a 72 px number you can step or type, the date
 * as a button that opens the month grid (no native "09/27/2026" field, no time), "Mentés" and the keyboard hint.
 * Prefilled with the last weight. The API can only create and delete, so an edit is "create the new entry, then delete
 * the old one" in one action, and saving onto a day that already has an entry replaces it after a confirm.
 * Mounted per opening (`key` at the call site), so its state starts from the entry / last weight each time.
 */
export function LogWeightDrawer({
  weights,
  editing,
  onClose,
}: {
  weights: WeightResponse[];
  /** The entry being edited, or null for a new one. */
  editing: WeightResponse | null;
  onClose: () => void;
}) {
  const t = useTranslations("weight");
  const common = useTranslations("common");
  const fmt = useFormat();
  const queryClient = useQueryClient();
  const { show } = useToast();
  const startWeight = initialWeight(weights, editing);
  const [startDate] = useState(() => (editing ? parseLocalDate(editing.date) : new Date()));
  const [weight, setWeight] = useState(startWeight);
  const [date, setDate] = useState(startDate);
  const startNote = editing?.note ?? "";
  const [note, setNote] = useState(startNote);
  const [calendarOpen, setCalendarOpen] = useState(false);
  const [pending, setPending] = useState<WeightSavePlan | null>(null);
  const dateText = format(date, "yyyy-MM-dd");
  const dirty = weight !== startWeight || dateText !== format(startDate, "yyyy-MM-dd") || note !== startNote;

  const saveMutation = useMutation({
    mutationFn: async (plan: WeightSavePlan) => {
      await weightApi.create(plan.create);
      for (const id of plan.deleteIds) await weightApi.delete(id);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.weights.all() });
      show(editing ? t("updated") : t("logged"), "success");
      onClose();
    },
    onError: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.weights.all() });
      show(t("saveFailed"), "error");
    },
  });

  // `kg` overrides the state for Enter, which commits the typed text and saves in the same tick.
  function save(kg: number = weight) {
    if (saveMutation.isPending) return;
    const plan = planWeightSave(weights, editing, dateText, kg, note);
    if (plan.conflicts.length > 0) setPending(plan);
    else saveMutation.mutate(plan);
  }

  return (
    <>
      <Drawer
        open
        onClose={onClose}
        width={480}
        title={editing ? t("editTitle") : t("logTitle")}
        isDirty={dirty}
        footer={
          <Button className="w-full" onClick={() => save()} disabled={saveMutation.isPending}>
            {saveMutation.isPending ? common("saving") : common("save")}
          </Button>
        }
      >
        <div className="flex flex-col gap-6 py-2">
          <WeightStepper value={weight} onChange={setWeight} onEnter={(kg) => save(kg)} />
          <p className="type-body-s text-center" style={{ color: "var(--text-3)" }}>
            {t("logHint")}
          </p>

          <div className="flex flex-col gap-2">
            <span className="type-label" style={{ color: "var(--text-3)" }}>
              {t("date")}
            </span>
            <div>
              <DateButton value={date} onClick={() => setCalendarOpen((o) => !o)} />
            </div>
            {calendarOpen && (
              <CalendarPopover
                value={date}
                onChange={(d) => {
                  setDate(d);
                  setCalendarOpen(false);
                }}
                disableFuture
                hasData={(d) => weights.some((w) => w.date === format(d, "yyyy-MM-dd"))}
              />
            )}
          </div>

          <TextField
            label={t("note")}
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder={t("notePlaceholder")}
            maxLength={WEIGHT_NOTE_MAX}
            data-testid="weight-note"
          />
        </div>
      </Drawer>

      <ConfirmModal
        open={pending != null}
        onClose={() => setPending(null)}
        onConfirm={() => {
          if (pending) saveMutation.mutate(pending);
          setPending(null);
        }}
        icon="event_repeat"
        tint="var(--primary)"
        destructive={false}
        title={t("replaceTitle")}
        body={pending ? t("replaceBody", { weights: pending.conflicts.map((c) => fmt.weight(c.weight)).join(", ") }) : ""}
        cancelLabel={common("cancel")}
        confirmLabel={t("replaceConfirm")}
      />
    </>
  );
}
