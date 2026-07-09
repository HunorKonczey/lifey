"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";

interface PostWorkoutFeedbackDialogProps {
  open: boolean;
  initialRpe: number | null;
  initialNote: string | null;
  onSkip: () => void;
  onSave: (rpe: number, note: string | null) => void;
}

const RPE_VALUES = Array.from({ length: 10 }, (_, i) => i + 1);

/**
 * "How hard was this workout?" modal — a 1-10 difficulty (RPE) selector plus
 * an optional note. Fully skippable. Used both right after finishing a
 * session and to edit an already-saved rating from the session view.
 */
export function PostWorkoutFeedbackDialog({
  open,
  initialRpe,
  initialNote,
  onSkip,
  onSave,
}: PostWorkoutFeedbackDialogProps) {
  const t = useTranslations("workouts");
  const common = useTranslations("common");
  const [rpe, setRpe] = useState<number | null>(initialRpe);
  const [note, setNote] = useState(initialNote ?? "");

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      style={{ background: "rgba(0,0,0,.5)" }}
      onClick={onSkip}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-label={t("postWorkoutFeedbackTitle")}
        onClick={(e) => e.stopPropagation()}
        className="w-full max-w-md rounded-[var(--r-lg)] p-5 flex flex-col gap-4"
        style={{ background: "var(--surface)" }}
      >
        <h3 className="font-bold text-base">{t("postWorkoutFeedbackTitle")}</h3>

        <div>
          <div className="grid grid-cols-10 gap-1">
            {RPE_VALUES.map((v) => (
              <button
                key={v}
                onClick={() => setRpe(v)}
                className="h-9 rounded-[var(--r-sm)] text-xs font-extrabold flex items-center justify-center transition-colors"
                style={{
                  background: rpe === v ? "var(--primary)" : "var(--surface-container)",
                  color: rpe === v ? "#1E1F18" : "var(--on-surface-variant)",
                }}
              >
                {v}
              </button>
            ))}
          </div>
          <div
            className="flex items-center justify-between text-[11px] font-semibold mt-1.5"
            style={{ color: "var(--muted)" }}
          >
            <span>{t("postWorkoutFeedbackAnchorEasy")}</span>
            <span>{t("postWorkoutFeedbackAnchorMax")}</span>
          </div>
        </div>

        <textarea
          value={note}
          onChange={(e) => setNote(e.target.value)}
          rows={3}
          placeholder={t("postWorkoutFeedbackNotePlaceholder")}
          className="w-full px-3 py-2 rounded-[var(--r-input)] text-sm outline-none resize-none"
          style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}
        />

        <div className="flex gap-2">
          <button
            onClick={onSkip}
            className="flex-1 h-11 rounded-[var(--r-input)] font-semibold text-sm"
            style={{ background: "var(--surface-highest)", color: "var(--on-surface)" }}
          >
            {t("postWorkoutFeedbackSkip")}
          </button>
          <button
            onClick={() => rpe != null && onSave(rpe, note.trim() || null)}
            disabled={rpe == null}
            className="flex-1 h-11 rounded-[var(--r-input)] font-semibold text-sm disabled:opacity-40"
            style={{ background: "var(--primary)", color: "#1E1F18" }}
          >
            {common("save")}
          </button>
        </div>
      </div>
    </div>
  );
}
