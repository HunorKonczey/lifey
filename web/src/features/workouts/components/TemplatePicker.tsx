"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { Button, Icon, IconButton, Modal } from "@/components/ds";
import { TemplateTile } from "./TemplateTile";
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
            {items.map((item) => (
              <TemplateTile
                key={item.template.id}
                item={item}
                radio
                selected={item.template.id === selectedId}
                onClick={() => setPicked(item.template.id)}
                onDoubleClick={() => !starting && onStart(item.template)}
              />
            ))}
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
