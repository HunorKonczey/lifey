"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { templateApi } from "@/features/workouts/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { Dialog } from "@/components/ui/Dialog";
import { TimePicker } from "@/components/ui/TimePicker";
import { ErrorState } from "@/components/status/ErrorState";
import {
  DAYS_OF_WEEK,
  findSlot,
  setSlot,
  clearSlot,
  duplicateWeek,
  copyWeekToAll,
  dropOverflowWeeks,
  validateProgram,
  isProgramValid,
  MIN_WEEKS,
  MAX_WEEKS,
} from "../program";
import type { DayOfWeek, ProgramWorkoutRequest } from "../types";

interface ProgramGridEditorProps {
  initialName: string;
  initialWeeksCount: number;
  initialWorkouts: ProgramWorkoutRequest[];
  onSave: (data: { name: string; weeksCount: number; workouts: ProgramWorkoutRequest[] }) => void;
  saving: boolean;
  saveLabel: string;
  savingLabel: string;
}

export function ProgramGridEditor({
  initialName, initialWeeksCount, initialWorkouts, onSave, saving, saveLabel, savingLabel,
}: ProgramGridEditorProps) {
  const t = useTranslations("admin.programs");
  const [name, setName] = useState(initialName);
  const [weeksCount, setWeeksCount] = useState(initialWeeksCount);
  const [workouts, setWorkouts] = useState(initialWorkouts);
  const [editingSlot, setEditingSlot] = useState<{ week: number; day: DayOfWeek } | null>(null);

  const templatesQ = useQuery({ queryKey: queryKeys.workoutTemplates.all(), queryFn: templateApi.list });

  const validation = validateProgram(name, weeksCount, workouts);

  /**
   * Takes a delta (not an absolute value) and updates both states via functional
   * updaters — reading `weeksCount` from the render closure would compute the
   * same stale value for two clicks batched into one React update, silently
   * swallowing the second click.
   */
  const changeWeeksCount = (delta: number) => {
    setWeeksCount((prev) => {
      const clamped = Math.min(MAX_WEEKS, Math.max(MIN_WEEKS, prev + delta));
      setWorkouts((w) => dropOverflowWeeks(w, clamped));
      return clamped;
    });
  };

  const templateName = (templateId: number) =>
    (templatesQ.data ?? []).find((tpl) => tpl.id === templateId)?.name ?? `#${templateId}`;

  const weeks = Array.from({ length: weeksCount }, (_, i) => i + 1);

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-end gap-4">
        <div className="flex flex-col gap-1.5 flex-1 min-w-[220px]">
          <label className="text-[11px] font-bold tracking-wider uppercase" style={{ color: "var(--muted)" }}>
            {t("nameLabel")}
          </label>
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder={t("namePlaceholder")}
            data-testid="program-name-input"
            className="h-11 rounded-2xl px-4 text-sm outline-none"
            style={{
              background: "var(--surface)",
              color: "var(--on-surface)",
              border: `1px solid ${validation.nameError ? "var(--error)" : "transparent"}`,
            }}
          />
        </div>

        <div className="flex flex-col gap-1.5">
          <label className="text-[11px] font-bold tracking-wider uppercase" style={{ color: "var(--muted)" }}>
            {t("weeksLabel")}
          </label>
          <div className="flex items-center gap-2 rounded-2xl h-11 px-2" style={{ background: "var(--surface)" }}>
            <button
              type="button"
              onClick={() => changeWeeksCount(-1)}
              disabled={weeksCount <= MIN_WEEKS}
              className="w-8 h-8 rounded-full flex items-center justify-center disabled:opacity-30"
              style={{ color: "var(--on-surface)" }}
              aria-label="-"
            >
              <span className="material-symbols-rounded text-lg">remove</span>
            </button>
            <span className="w-8 text-center text-sm font-bold tabular" style={{ color: "var(--on-surface)" }}>
              {weeksCount}
            </span>
            <button
              type="button"
              onClick={() => changeWeeksCount(1)}
              disabled={weeksCount >= MAX_WEEKS}
              className="w-8 h-8 rounded-full flex items-center justify-center disabled:opacity-30"
              style={{ color: "var(--on-surface)" }}
              aria-label="+"
            >
              <span className="material-symbols-rounded text-lg">add</span>
            </button>
          </div>
        </div>

        <button
          type="button"
          onClick={() => onSave({ name, weeksCount, workouts })}
          disabled={!isProgramValid(validation) || saving}
          data-testid="program-save-button"
          className="h-11 px-6 rounded-2xl text-[13.5px] font-extrabold disabled:opacity-40"
          style={{ background: "var(--tertiary)", color: "#161611" }}
        >
          {saving ? savingLabel : saveLabel}
        </button>
      </div>

      {(validation.nameError || validation.weeksCountError || validation.noSlotsError) && (
        <div className="flex flex-col gap-1 text-xs" style={{ color: "var(--error)" }}>
          {validation.nameError && <span>{t("nameRequired")}</span>}
          {validation.weeksCountError && <span>{t("weeksOutOfRange")}</span>}
          {validation.noSlotsError && <span>{t("noSlots")}</span>}
        </div>
      )}

      <div className="flex flex-col gap-2 overflow-x-auto">
        <div className="grid gap-2" style={{ gridTemplateColumns: "70px repeat(7, minmax(120px, 1fr))", minWidth: 760 }}>
          <div />
          {DAYS_OF_WEEK.map((day) => (
            <div key={day} className="text-[11px] font-bold tracking-wider uppercase text-center py-1" style={{ color: "var(--muted)" }}>
              {t(`days.${day}`)}
            </div>
          ))}

          {weeks.map((week) => (
            <WeekRow
              key={week}
              week={week}
              weeksCount={weeksCount}
              workouts={workouts}
              templateName={templateName}
              onCellClick={(day) => setEditingSlot({ week, day })}
              onDuplicateBelow={() => setWorkouts((prev) => duplicateWeek(prev, week, week + 1))}
              onCopyToAll={() => setWorkouts((prev) => copyWeekToAll(prev, week, weeksCount))}
            />
          ))}
        </div>
      </div>

      {editingSlot && (
        <SlotEditorDialog
          week={editingSlot.week}
          day={editingSlot.day}
          existing={findSlot(workouts, editingSlot.week, editingSlot.day)}
          templates={templatesQ.data ?? []}
          templatesError={templatesQ.isError}
          onRetryTemplates={() => templatesQ.refetch()}
          onSave={(slot) => {
            setWorkouts((prev) => setSlot(prev, slot));
            setEditingSlot(null);
          }}
          onClear={() => {
            setWorkouts((prev) => clearSlot(prev, editingSlot.week, editingSlot.day));
            setEditingSlot(null);
          }}
          onClose={() => setEditingSlot(null)}
        />
      )}
    </div>
  );
}

interface WeekRowProps {
  week: number;
  weeksCount: number;
  workouts: ProgramWorkoutRequest[];
  templateName: (id: number) => string;
  onCellClick: (day: DayOfWeek) => void;
  onDuplicateBelow: () => void;
  onCopyToAll: () => void;
}

function WeekRow({ week, weeksCount, workouts, templateName, onCellClick, onDuplicateBelow, onCopyToAll }: WeekRowProps) {
  const t = useTranslations("admin.programs");
  return (
    <>
      <div className="flex flex-col gap-1 justify-center">
        <span className="text-[12px] font-extrabold" style={{ color: "var(--on-surface)" }}>{t("week", { number: week })}</span>
        <div className="flex flex-col gap-0.5">
          {week < weeksCount && (
            <button
              type="button"
              onClick={onDuplicateBelow}
              className="text-[10px] font-semibold text-left"
              style={{ color: "var(--tertiary)" }}
            >
              {t("duplicateWeekBelow")}
            </button>
          )}
          {weeksCount > 1 && (
            <button
              type="button"
              onClick={onCopyToAll}
              className="text-[10px] font-semibold text-left"
              style={{ color: "var(--tertiary)" }}
            >
              {t("copyWeekToAll")}
            </button>
          )}
        </div>
      </div>
      {DAYS_OF_WEEK.map((day) => {
        const slot = findSlot(workouts, week, day);
        return (
          <button
            key={day}
            type="button"
            data-testid={`program-cell-${week}-${day}`}
            onClick={() => onCellClick(day)}
            className="rounded-2xl p-2.5 min-h-[62px] flex flex-col items-start justify-center gap-0.5 text-left transition-colors"
            style={{
              background: slot ? "rgba(110,154,106,.14)" : "var(--surface)",
              border: slot ? "1.5px solid var(--tertiary)" : "1.5px solid transparent",
            }}
          >
            {slot ? (
              <>
                <span className="text-[12px] font-bold truncate w-full" style={{ color: "var(--on-surface)" }}>
                  {templateName(slot.templateId)}
                </span>
                {slot.timeOfDay && (
                  <span className="text-[10px]" style={{ color: "var(--on-surface-variant)" }}>{slot.timeOfDay}</span>
                )}
              </>
            ) : (
              <span className="text-[11px]" style={{ color: "var(--muted)" }}>{t("emptySlot")}</span>
            )}
          </button>
        );
      })}
    </>
  );
}

interface SlotEditorDialogProps {
  week: number;
  day: DayOfWeek;
  existing?: ProgramWorkoutRequest;
  templates: { id: number; name: string }[];
  templatesError: boolean;
  onRetryTemplates: () => void;
  onSave: (slot: ProgramWorkoutRequest) => void;
  onClear: () => void;
  onClose: () => void;
}

function SlotEditorDialog({
  week, day, existing, templates, templatesError, onRetryTemplates, onSave, onClear, onClose,
}: SlotEditorDialogProps) {
  const t = useTranslations("admin.programs");
  const [search, setSearch] = useState("");
  const [templateId, setTemplateId] = useState<number | null>(existing?.templateId ?? null);
  const [timeOfDay, setTimeOfDay] = useState(existing?.timeOfDay ?? "");
  const [note, setNote] = useState(existing?.note ?? "");

  const filtered = templates.filter((tpl) => tpl.name.toLowerCase().includes(search.toLowerCase()));

  return (
    <Dialog open onClose={onClose} title={`${t("week", { number: week })} · ${t(`days.${day}`)}`}>
      <div className="flex flex-col gap-4">
        <div className="flex flex-col gap-2">
          <p className="text-[11px] font-bold tracking-wider uppercase" style={{ color: "var(--muted)" }}>
            {t("pickTemplate")}
          </p>
          <div className="rounded-2xl h-11 flex items-center gap-2.5 px-4" style={{ background: "var(--surface-container)" }}>
            <span className="material-symbols-rounded text-lg" style={{ color: "var(--muted)" }}>search</span>
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder={t("searchTemplatePlaceholder")}
              className="flex-1 bg-transparent outline-none text-sm"
              style={{ color: "var(--on-surface)" }}
            />
          </div>
          <div className="flex flex-col gap-1.5 max-h-[180px] overflow-y-auto">
            {templatesError ? (
              <ErrorState inline onRetry={onRetryTemplates} />
            ) : filtered.length === 0 ? (
              <p className="text-xs text-center py-3" style={{ color: "var(--muted)" }}>{t("noTemplatesFound")}</p>
            ) : (
              filtered.map((tpl) => {
                const selected = tpl.id === templateId;
                return (
                  <button
                    key={tpl.id}
                    type="button"
                    data-testid="program-slot-template-row"
                    onClick={() => setTemplateId(tpl.id)}
                    className="flex items-center gap-3 rounded-2xl px-3 py-2.5 transition-colors text-left"
                    style={{
                      background: selected ? "rgba(110,154,106,.14)" : "transparent",
                      border: selected ? "1.5px solid var(--tertiary)" : "1.5px solid transparent",
                    }}
                  >
                    <span
                      className="w-9 h-9 rounded-xl flex items-center justify-center shrink-0"
                      style={{ background: "var(--surface-container)", color: "var(--tertiary)" }}
                    >
                      <span className="material-symbols-rounded text-lg">fitness_center</span>
                    </span>
                    <span className="flex-1 min-w-0 text-[13.5px] font-bold truncate" style={{ color: "var(--on-surface)" }}>
                      {tpl.name}
                    </span>
                    {selected && (
                      <span className="material-symbols-rounded text-xl" style={{ color: "var(--tertiary)", fontVariationSettings: "'FILL' 1" }}>
                        check_circle
                      </span>
                    )}
                  </button>
                );
              })
            )}
          </div>
        </div>

        <div className="flex flex-col gap-1">
          <label className="text-[11px] font-semibold" style={{ color: "var(--muted)" }}>{t("timeOfDay")}</label>
          <TimePicker value={timeOfDay} onChange={setTimeOfDay} />
        </div>

        <div className="flex flex-col gap-1">
          <label className="text-[11px] font-semibold" style={{ color: "var(--muted)" }}>{t("note")}</label>
          <textarea
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder={t("notePlaceholder")}
            rows={2}
            maxLength={500}
            className="rounded-2xl px-3.5 py-2.5 text-sm outline-none resize-none"
            style={{ background: "var(--surface-container)", color: "var(--on-surface)" }}
          />
        </div>

        <div className="flex gap-2.5 pt-2">
          {existing && (
            <button
              type="button"
              onClick={onClear}
              className="flex-1 text-center text-[13.5px] font-bold py-3 rounded-2xl"
              style={{ color: "var(--error)" }}
            >
              {t("clearSlot")}
            </button>
          )}
          <button
            type="button"
            onClick={onClose}
            className="flex-1 text-center text-[13.5px] font-bold py-3 rounded-2xl"
            style={{ color: "var(--on-surface-variant)" }}
          >
            {t("cancel")}
          </button>
          <button
            type="button"
            disabled={templateId == null}
            data-testid="program-slot-save"
            onClick={() =>
              onSave({ weekNumber: week, dayOfWeek: day, templateId: templateId as number, timeOfDay: timeOfDay || null, note: note || null })
            }
            className="flex-[2] text-center rounded-2xl py-3 text-[13.5px] font-extrabold disabled:opacity-40"
            style={{ background: "var(--tertiary)", color: "#161611" }}
          >
            {t("save")}
          </button>
        </div>
      </div>
    </Dialog>
  );
}
