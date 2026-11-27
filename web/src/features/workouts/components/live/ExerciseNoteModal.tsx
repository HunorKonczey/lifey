"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { Button, Modal, TextArea } from "@/components/ds";
import { EXERCISE_NOTE_MAX_LENGTH, normalizeExerciseNote } from "../../exerciseNotes";

/**
 * The exercise's comment editor in the live logger (LIF-226), the web twin of mobile's `ExerciseNoteEditor`: one
 * text area (max 1000), the previous session's comment underneath for reference, "Mégse" / "Mentés". Emptying the
 * field and saving removes the comment. Esc = Mégse.
 */
export function ExerciseNoteModal({
  open,
  exerciseName,
  initialNote,
  previousNote,
  onCancel,
  onSave,
}: {
  open: boolean;
  exerciseName: string;
  initialNote: string | null;
  /** The comment from the exercise's last session, shown for reference; null when it had none. */
  previousNote: string | null;
  onCancel: () => void;
  onSave: (note: string | null) => void;
}) {
  const t = useTranslations("workouts");
  const [note, setNote] = useState(initialNote ?? "");

  return (
    <Modal open={open} onClose={onCancel} width={480} aria-label={t("exerciseNote")}>
      <div className="flex flex-col gap-4 p-6">
        <div>
          <h2 className="type-title-l">{t("exerciseNote")}</h2>
          <p className="type-body-s mt-1" style={{ color: "var(--text-2)" }}>
            {exerciseName}
          </p>
        </div>

        <TextArea
          rows={3}
          autoFocus
          value={note}
          maxLength={EXERCISE_NOTE_MAX_LENGTH}
          onChange={(e) => setNote(e.target.value)}
          placeholder={t("exerciseNoteHint")}
          aria-label={t("exerciseNote")}
        />

        {previousNote && (
          <p
            className="type-body-s break-words whitespace-pre-line"
            style={{ color: "var(--text-2)" }}
          >
            {t("exerciseNotePrevious", { note: previousNote })}
          </p>
        )}

        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onCancel}>
            {t("exerciseNoteCancel")}
          </Button>
          <Button onClick={() => onSave(normalizeExerciseNote(note))}>
            {t("exerciseNoteSave")}
          </Button>
        </div>
      </div>
    </Modal>
  );
}
