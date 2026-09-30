"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { Button, Icon, IconButton, Modal, TintedChip } from "@/components/ds";
import { pickerTemplates } from "../templatePicker";
import type { WorkoutSessionResponse, WorkoutTemplateResponse } from "../types";

/**
 * The "Edzés indítása" modal (W3.5, W3-F, fix2-002/003): template tiles with the exercise count, estimated time
 * and last-used day, the recommended one first and marked "Javasolt" and preselected, the selection a tint plus a
 * 2 px primary ring; "Üres edzés sablon nélkül" and "Indítás" at the bottom. Centred in both themes (`Modal`),
 * a bottom sheet under 768 px. Enter starts the selected one.
 */
export function TemplatePicker({
  open,
  onClose,
  templates,
  sessions,
  recommendedId,
  starting,
  onStart,
}: {
  open: boolean;
  onClose: () => void;
  templates: readonly WorkoutTemplateResponse[];
  /** All sessions, newest first. */
  sessions: WorkoutSessionResponse[];
  recommendedId: number | null;
  starting: boolean;
  /** `null` = an empty workout. */
  onStart: (template: WorkoutTemplateResponse | null) => void;
}) {
  const t = useTranslations("workouts");
  const items = pickerTemplates(templates, sessions, recommendedId, new Date());
  // The user's pick; until they make one the recommended tile (else the first) is selected.
  const [picked, setPicked] = useState<number | null>(null);
  const selectedId = picked != null && items.some((i) => i.template.id === picked) ? picked : (items[0]?.template.id ?? null);
  const selected = items.find((i) => i.template.id === selectedId)?.template ?? null;

  const daysAgoLabel = (days: number | null) =>
    days == null ? t("pickerNeverDone") : days === 0 ? t("pickerToday") : t("pickerDaysAgo", { count: days });

  return (
    <Modal open={open} onClose={onClose} width={480} aria-label={t("startWorkout")}>
      <div className="flex flex-col gap-4 p-6" onKeyDown={(e) => {
        if (e.key === "Enter" && !starting && (e.target as HTMLElement).tagName !== "BUTTON") onStart(selected);
      }}>
        <div className="flex items-center justify-between gap-3">
          <h2 className="type-title-l">{t("startWorkout")}</h2>
          <IconButton icon="close" label={t("pickerClose")} onClick={onClose} />
        </div>

        {items.length === 0 ? (
          <p className="type-body-s" style={{ color: "var(--text-3)" }}>
            {t("noTemplatesYet")}
          </p>
        ) : (
          <div role="radiogroup" aria-label={t("fromTemplate")} className="flex flex-col gap-2">
            {items.map((item) => {
              const on = item.template.id === selectedId;
              return (
                <button
                  key={item.template.id}
                  type="button"
                  role="radio"
                  aria-checked={on}
                  onClick={() => setPicked(item.template.id)}
                  onDoubleClick={() => !starting && onStart(item.template)}
                  className="lifey-button flex items-center gap-3 p-3 text-left"
                  style={{
                    borderRadius: "var(--r-card)",
                    background: on ? "var(--primary-tint)" : "var(--nested)",
                    boxShadow: on ? "inset 0 0 0 2px var(--primary)" : undefined,
                  }}
                >
                  <span
                    className="flex flex-none items-center justify-center"
                    style={{ width: 40, height: 40, borderRadius: 12, background: "color-mix(in srgb, var(--primary) var(--chip-tint), transparent)", color: "var(--primary)" }}
                  >
                    <Icon name="list_alt" size={22} />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="flex flex-wrap items-center gap-2">
                      <span className="type-body truncate" style={{ fontWeight: 700 }}>
                        {item.template.name}
                      </span>
                      {item.recommended && <TintedChip label={t("recommendedBadge")} color="var(--primary)" />}
                    </span>
                    <span className="type-body-s block" style={{ color: "var(--text-2)" }}>
                      {t("pickerMeta", { exercises: item.exerciseCount, minutes: item.estimatedMinutes })}
                    </span>
                  </span>
                  <span className="type-body-s flex-none" style={{ color: "var(--text-3)" }}>
                    {daysAgoLabel(item.daysAgo)}
                  </span>
                </button>
              );
            })}
          </div>
        )}

        <div className="flex flex-wrap items-center justify-between gap-2 pt-1">
          <Button variant="ghost" onClick={() => onStart(null)} disabled={starting}>
            {t("pickerEmpty")}
          </Button>
          <Button onClick={() => onStart(selected)} disabled={starting || selected == null}>
            <Icon name="play_arrow" size={20} />
            {t("pickerStart")}
          </Button>
        </div>
      </div>
    </Modal>
  );
}
