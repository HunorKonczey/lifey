"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { Button, Modal, TextArea } from "@/components/ds";

const RPE_VALUES = Array.from({ length: 10 }, (_, i) => i + 1);

/**
 * "Milyen nehéz volt?" (W3.9, W3-C, live-003/finish-001): ten RPE chips, the selected one named underneath
 * ("7 · Kemény, de ment"), an optional note, "Kihagyás" and "Tovább". Used right before a workout is finished
 * (Kihagyás still finishes it) and to change a saved rating from a finished workout. Esc = Kihagyás.
 */
export function RpeModal({
  open,
  initialRpe,
  initialNote,
  onSkip,
  onContinue,
}: {
  open: boolean;
  initialRpe: number | null;
  initialNote: string | null;
  onSkip: () => void;
  onContinue: (rpe: number, note: string | null) => void;
}) {
  const t = useTranslations("workouts");
  const [rpe, setRpe] = useState<number | null>(initialRpe);
  const [note, setNote] = useState(initialNote ?? "");

  return (
    <Modal open={open} onClose={onSkip} width={480} aria-label={t("rpeTitle")}>
      <div className="flex flex-col gap-4 p-6">
        <div>
          <h2 className="type-title-l">{t("rpeTitle")}</h2>
          <p className="type-body-s mt-1" style={{ color: "var(--text-2)" }}>
            {t("rpeBody")}
          </p>
        </div>

        <div>
          <div role="radiogroup" aria-label={t("rpeTitle")} className="grid grid-cols-5 gap-2 sm:grid-cols-10">
            {RPE_VALUES.map((v) => {
              const on = rpe === v;
              return (
                <button
                  key={v}
                  type="button"
                  role="radio"
                  aria-checked={on}
                  onClick={() => setRpe(v)}
                  className="lifey-button tabular flex items-center justify-center"
                  style={{
                    height: 44,
                    borderRadius: "var(--r-control)",
                    fontWeight: 800,
                    background: on ? "var(--primary)" : "var(--nested)",
                    color: on ? "var(--on-primary)" : "var(--text-2)",
                  }}
                >
                  {v}
                </button>
              );
            })}
          </div>
          <p className="type-body-s mt-2" style={{ color: rpe != null ? "var(--text)" : "var(--text-3)", fontWeight: rpe != null ? 700 : 500 }} aria-live="polite">
            {rpe != null ? `${rpe} · ${t(`rpeLevel${rpe}`)}` : t("rpeHint")}
          </p>
        </div>

        <TextArea rows={2} value={note} onChange={(e) => setNote(e.target.value)} placeholder={t("postWorkoutFeedbackNotePlaceholder")} aria-label={t("postWorkoutFeedbackNotePlaceholder")} />

        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onSkip}>
            {t("postWorkoutFeedbackSkip")}
          </Button>
          <Button onClick={() => rpe != null && onContinue(rpe, note.trim() || null)} disabled={rpe == null}>
            {t("rpeContinue")}
          </Button>
        </div>
      </div>
    </Modal>
  );
}
