"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { Button, Icon, NumberField, SelectField, TextArea, TextField } from "@/components/ds";
import { EQUIPMENT, MUSCLE_GROUPS, type Equipment, type ExerciseRequest, type ExerciseResponse, type MuscleGroup } from "../types";

/** What the editor holds — strings and a number so the fields are controlled; `rest` empty = "use my default". */
interface Fields {
  name: string;
  category: string;
  equipment: string;
  description: string;
  rest: number | null;
}

const fieldsOf = (e: ExerciseResponse | null): Fields => ({
  name: e?.name ?? "",
  category: e?.category ?? "",
  equipment: e?.equipment ?? "",
  description: e?.description ?? "",
  rest: e?.defaultRestSeconds ?? null,
});

/** The wire request for the edited fields. */
export function exerciseRequest(f: Fields): ExerciseRequest {
  return {
    name: f.name.trim(),
    category: (f.category || null) as MuscleGroup | null,
    equipment: (f.equipment || null) as Equipment | null,
    description: f.description.trim() || null,
    defaultRestSeconds: f.rest,
  };
}

export function isExerciseDirty(exercise: ExerciseResponse | null, f: Fields): boolean {
  const base = fieldsOf(exercise);
  return (Object.keys(base) as (keyof Fields)[]).some((k) => (k === "name" || k === "description" ? base[k].trim() !== (f[k] as string).trim() : base[k] !== f[k]));
}

/**
 * The exercise editor (W3.12): name, muscle group, equipment, description and — new on the web — the rest after a
 * set of this exercise ("Pihenő"; empty = the user's default from Settings), which the live logger's rest timer
 * reads. A side panel from 1280 px, a drawer below (`bare` drops the heading). Delete is the table row's "⋯" job.
 */
export function ExerciseEditorPanel({
  exercise,
  pending,
  bare = false,
  onDirtyChange,
  onSave,
  onCancel,
}: {
  exercise: ExerciseResponse | null;
  pending: boolean;
  bare?: boolean;
  onDirtyChange?: (dirty: boolean) => void;
  onSave: (request: ExerciseRequest) => void;
  onCancel: () => void;
}) {
  const t = useTranslations("workouts");
  const tm = useTranslations("workouts.muscleGroups");
  const te = useTranslations("workouts.equipmentTypes");
  const common = useTranslations("common");
  const [fields, setFields] = useState<Fields>(() => fieldsOf(exercise));
  const set = <K extends keyof Fields>(key: K, value: Fields[K]) => setFields((f) => ({ ...f, [key]: value }));

  const dirty = isExerciseDirty(exercise, fields);
  useEffect(() => {
    onDirtyChange?.(dirty);
  }, [dirty, onDirtyChange]);

  return (
    <div className="flex flex-col gap-4" data-testid="exercise-editor">
      {!bare && <h2 className="type-title">{exercise ? t("editExercise") : t("newExerciseTitle")}</h2>}

      <TextField label={t("exerciseName")} value={fields.name} onChange={(e) => set("name", e.target.value)} autoFocus={!exercise} />

      <SelectField label={t("category")} value={fields.category} onChange={(e) => set("category", e.target.value)}>
        <option value="">{common("noneOption")}</option>
        {MUSCLE_GROUPS.map((g) => (
          <option key={g} value={g}>
            {tm(g)}
          </option>
        ))}
      </SelectField>

      <SelectField label={t("equipment")} value={fields.equipment} onChange={(e) => set("equipment", e.target.value)}>
        <option value="">{common("noneOption")}</option>
        {EQUIPMENT.map((q) => (
          <option key={q} value={q}>
            {te(q)}
          </option>
        ))}
      </SelectField>

      <div>
        <NumberField
          label={t("restLabel")}
          hint={t("restHint")}
          value={fields.rest ?? 0}
          onChange={(v) => set("rest", v > 0 ? v : null)}
          unit="s"
          step={15}
          min={0}
          max={900}
          maxDecimals={0}
        />
        {fields.rest != null && (
          <Button variant="ghost" className="mt-1" onClick={() => set("rest", null)}>
            <Icon name="restart_alt" size={18} />
            {t("restUseDefault")}
          </Button>
        )}
      </div>

      <TextArea label={t("exerciseDescription")} rows={3} value={fields.description} onChange={(e) => set("description", e.target.value)} />

      <div className="flex gap-2">
        <Button className="flex-1" onClick={() => onSave(exerciseRequest(fields))} disabled={!fields.name.trim() || pending}>
          {pending ? common("saving") : common("save")}
        </Button>
        <Button variant="secondary" onClick={onCancel}>
          {common("cancel")}
        </Button>
      </div>
    </div>
  );
}
