"use client";

import { useEffect, useMemo, useState } from "react";
import { DndContext, DragOverlay, pointerWithin, PointerSensor, useSensor, useSensors, type DragEndEvent, type DragStartEvent } from "@dnd-kit/core";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { templateApi } from "@/features/workouts/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { Button, Checkbox, Icon, Modal, SelectField, TextArea, TextField, TimeField } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import {
  clearSlot,
  copyWeek,
  dropOverflowWeeks,
  findSlot,
  moveSlot,
  placeTemplate,
  isProgramValid,
  MAX_WEEKS,
  MIN_WEEKS,
  setSlot,
  validateProgram,
} from "../program";
import { ProgramTemplateRail } from "./ProgramTemplateRail";
import { ProgramWeekGrid } from "./ProgramWeekGrid";
import type { DayOfWeek, ProgramWorkoutRequest } from "../types";

interface ProgramGridEditorProps {
  initialName: string;
  initialWeeksCount: number;
  initialWorkouts: ProgramWorkoutRequest[];
  /** Resolves once the program is saved — the editor then shows "Mentve". */
  onSave: (data: { name: string; weeksCount: number; workouts: ProgramWorkoutRequest[] }) => Promise<unknown>;
  saving: boolean;
  saveLabel: string;
  savingLabel: string;
  /** How many clients are on this program now (an existing program only). */
  activeAssignmentCount?: number;
  /** "Kiosztás" — only an existing program can be assigned. */
  onAssign?: () => void;
}

const snapshotOf = (name: string, weeksCount: number, workouts: ProgramWorkoutRequest[]) =>
  JSON.stringify({ name: name.trim(), weeksCount, workouts: [...workouts].sort((a, b) => a.weekNumber - b.weekNumber || a.dayOfWeek.localeCompare(b.dayOfWeek)) });

/**
 * The program editor (W8-B): a header with the name, the meta line ("4 hét · 12 edzés · 3 kliens használja · Nem mentett
 * változás"), the weeks stepper and Mentés / Kiosztás; below it the template rail on the left and the week grid on the
 * right. A cell takes the picked template on click or Enter; a filled cell opens its slot (time, note, clear).
 */
export function ProgramGridEditor({ initialName, initialWeeksCount, initialWorkouts, onSave, saving, saveLabel, savingLabel, activeAssignmentCount, onAssign }: ProgramGridEditorProps) {
  const t = useTranslations("admin.programs");
  const fmt = useFormat();
  const [name, setName] = useState(initialName);
  const [weeksCount, setWeeksCount] = useState(initialWeeksCount);
  const [workouts, setWorkouts] = useState(initialWorkouts);
  const [pickedTemplate, setPickedTemplate] = useState<number | null>(null);
  const [editingSlot, setEditingSlot] = useState<{ week: number; day: DayOfWeek } | null>(null);
  const [copying, setCopying] = useState(false);
  const [drag, setDrag] = useState<{ label: string; slotKey: string | null } | null>(null);
  const [saved, setSaved] = useState(() => ({ snapshot: snapshotOf(initialName, initialWeeksCount, initialWorkouts), at: null as Date | null }));

  const templatesQ = useQuery({ queryKey: queryKeys.workoutTemplates.all(), queryFn: templateApi.list });
  const templates = useMemo(() => templatesQ.data ?? [], [templatesQ.data]);
  const validation = validateProgram(name, weeksCount, workouts);
  const dirty = snapshotOf(name, weeksCount, workouts) !== saved.snapshot;

  // Leaving with unsaved work asks first (the browser's own prompt).
  useEffect(() => {
    if (!dirty) return;
    const warn = (e: BeforeUnloadEvent) => e.preventDefault();
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [dirty]);

  /**
   * Takes a delta (not an absolute value) and updates both states via functional updaters — reading `weeksCount` from
   * the render closure would compute the same stale value for two clicks batched into one React update.
   */
  const changeWeeksCount = (delta: number) => {
    setWeeksCount((prev) => {
      const clamped = Math.min(MAX_WEEKS, Math.max(MIN_WEEKS, prev + delta));
      setWorkouts((w) => dropOverflowWeeks(w, clamped));
      return clamped;
    });
  };

  const templateName = (id: number) => templates.find((tpl) => tpl.id === id)?.name ?? `#${id}`;
  const templateExercises = (id: number) => templates.find((tpl) => tpl.id === id)?.exercises.length ?? null;

  const place = (week: number, day: DayOfWeek, templateId: number) => setWorkouts((prev) => placeTemplate(prev, week, day, templateId));

  const onCell = (week: number, day: DayOfWeek) => {
    if (pickedTemplate != null) place(week, day, pickedTemplate);
    else setEditingSlot({ week, day });
  };

  const save = async () => {
    await onSave({ name, weeksCount, workouts });
    setSaved({ snapshot: snapshotOf(name, weeksCount, workouts), at: new Date() });
  };

  // A drag starts after 6 px of movement, so a plain click on a tile still opens it. Pointer only, on purpose: the
  // keyboard (and screen-reader) way to place a workout is to pick a template row and press Enter on a cell, which is
  // shorter than stepping a dragged item across a 7-column grid. A KeyboardSensor with `pointerWithin` could not even
  // drop — there is no pointer to collide with (LIF-136).
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 6 } }));
  const onDragStart = (e: DragStartEvent) => {
    const data = e.active.data.current as { kind: "template"; templateId: number } | { kind: "slot"; week: number; day: DayOfWeek } | undefined;
    if (!data) return;
    if (data.kind === "template") setDrag({ label: templateName(data.templateId), slotKey: null });
    else {
      const from = findSlot(workouts, data.week, data.day);
      setDrag({ label: from ? templateName(from.templateId) : "", slotKey: `${data.week}-${data.day}` });
    }
  };
  const onDragEnd = (e: DragEndEvent) => {
    setDrag(null);
    const data = e.active.data.current as { kind: "template"; templateId: number } | { kind: "slot"; week: number; day: DayOfWeek } | undefined;
    const target = e.over?.data.current as { week: number; day: DayOfWeek } | undefined;
    if (!data || !target) return;
    if (data.kind === "template") place(target.week, target.day, data.templateId);
    else setWorkouts((prev) => moveSlot(prev, { weekNumber: data.week, dayOfWeek: data.day }, { weekNumber: target.week, dayOfWeek: target.day }));
  };

  const state = dirty ? t("unsaved") : saved.at ? t("savedAt", { when: fmt.relative(saved.at, new Date()) }) : t("savedPlain");

  return (
    <div className="flex flex-col gap-5">
      <header className="flex flex-col gap-3">
        <div className="flex flex-wrap items-center gap-3">
          <Link href="/admin/programs" aria-label={t("backToList")} className="lifey-button inline-flex items-center justify-center" style={{ width: 36, height: 36, borderRadius: "var(--r-control)", background: "var(--nested)" }}>
            <Icon name="arrow_back" size={20} />
          </Link>
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder={t("namePlaceholder")}
            aria-label={t("nameLabel")}
            aria-invalid={validation.nameError}
            data-testid="program-name-input"
            className="flex-1 min-w-[200px] bg-transparent outline-none"
            style={{ fontSize: 26, fontWeight: 800, letterSpacing: "-0.02em", borderBottom: `2px solid ${validation.nameError ? "var(--heart)" : "transparent"}` }}
          />
          <div className="flex items-center gap-1 pl-3 pr-1" style={{ height: 40, borderRadius: "var(--r-control)", background: "var(--control)" }} role="group" aria-label={t("weeksLabel")}>
            <span className="type-body-s" style={{ color: "var(--text-2)", fontWeight: 600 }}>{t("weeksLabel")}</span>
            <button type="button" onClick={() => changeWeeksCount(-1)} disabled={weeksCount <= MIN_WEEKS} aria-label="-" className="lifey-button inline-flex h-8 w-8 items-center justify-center disabled:opacity-30">
              <Icon name="remove" size={18} />
            </button>
            <span className="num text-center" style={{ minWidth: 22, fontWeight: 800 }}>{weeksCount}</span>
            <button type="button" onClick={() => changeWeeksCount(1)} disabled={weeksCount >= MAX_WEEKS} aria-label="+" className="lifey-button inline-flex h-8 w-8 items-center justify-center disabled:opacity-30">
              <Icon name="add" size={18} />
            </button>
          </div>
          <Button variant="secondary" onClick={() => setCopying(true)} disabled={weeksCount < 2} data-testid="program-copy-week">
            <Icon name="content_copy" size={18} />
            {t("copyWeekAction")}
          </Button>
          {onAssign && (
            <Button variant="secondary" onClick={onAssign} data-testid="program-assign-button">
              <Icon name="person_add" size={18} />
              {t("assignAction")}
            </Button>
          )}
          <Button onClick={save} disabled={!isProgramValid(validation) || saving || !dirty} data-testid="program-save-button">
            {saving ? savingLabel : saveLabel}
          </Button>
        </div>
        <p className="type-body-s" style={{ color: "var(--text-2)" }} aria-live="polite">
          {[t("metaWeeks", { count: weeksCount }), t("metaWorkouts", { count: workouts.length }), activeAssignmentCount != null ? t("metaUsers", { count: activeAssignmentCount }) : null].filter(Boolean).join(" · ")}
          {" · "}
          <span style={{ color: dirty ? "var(--primary)" : undefined, fontWeight: dirty ? 700 : 400 }}>{state}</span>
        </p>
        {(validation.nameError || validation.weeksCountError || validation.noSlotsError) && (
          <div className="flex flex-col gap-1 type-body-s" style={{ color: "var(--heart)" }} role="alert">
            {validation.nameError && <span>{t("nameRequired")}</span>}
            {validation.weeksCountError && <span>{t("weeksOutOfRange")}</span>}
            {validation.noSlotsError && <span>{t("noSlots")}</span>}
          </div>
        )}
      </header>

      <DndContext sensors={sensors} collisionDetection={pointerWithin} onDragStart={onDragStart} onDragEnd={onDragEnd} onDragCancel={() => setDrag(null)}>
      <div className="grid grid-cols-1 lg:grid-cols-[280px_minmax(0,1fr)] gap-5 items-start">
        <ProgramTemplateRail templates={templates} error={templatesQ.isError} onRetry={() => templatesQ.refetch()} selectedId={pickedTemplate} onSelect={setPickedTemplate} />
        <ProgramWeekGrid
          weeksCount={weeksCount}
          workouts={workouts}
          templateName={templateName}
          templateExercises={templateExercises}
          placing={pickedTemplate != null ? templateName(pickedTemplate) : null}
          onCell={onCell}
          dragging={drag?.slotKey ?? null}
        />
      </div>
      <DragOverlay dropAnimation={null}>
        {drag && (
          <div className="px-3.5 py-2.5" style={{ borderRadius: 12, background: "var(--card)", boxShadow: "var(--e2), inset 0 0 0 2px var(--primary)", fontWeight: 700 }}>
            {drag.label}
          </div>
        )}
      </DragOverlay>
      </DndContext>

      {copying && (
        <CopyWeekDialog
          weeksCount={weeksCount}
          workouts={workouts}
          onApply={(source, targets) => {
            setWorkouts((prev) => copyWeek(prev, source, targets));
            setCopying(false);
          }}
          onClose={() => setCopying(false)}
        />
      )}

      {editingSlot && (
        <SlotEditor
          key={`${editingSlot.week}-${editingSlot.day}`}
          week={editingSlot.week}
          day={editingSlot.day}
          existing={findSlot(workouts, editingSlot.week, editingSlot.day)}
          templates={templates}
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

interface SlotEditorProps {
  week: number;
  day: DayOfWeek;
  existing?: ProgramWorkoutRequest;
  templates: { id: number; name: string }[];
  onSave: (slot: ProgramWorkoutRequest) => void;
  onClear: () => void;
  onClose: () => void;
}

/** One cell's details (W8-B): which template, at what time, with what note — a short decision, so a DS modal. */
function SlotEditor({ week, day, existing, templates, onSave, onClear, onClose }: SlotEditorProps) {
  const t = useTranslations("admin.programs");
  const [search, setSearch] = useState("");
  const [templateId, setTemplateId] = useState<number | null>(existing?.templateId ?? null);
  const [timeOfDay, setTimeOfDay] = useState(existing?.timeOfDay ? existing.timeOfDay.slice(0, 5) : "");
  const [note, setNote] = useState(existing?.note ?? "");
  const filtered = templates.filter((tpl) => tpl.name.toLowerCase().includes(search.toLowerCase()));

  return (
    <Modal open onClose={onClose} width={480} aria-label={`${t("weekRowLabel", { number: week })} · ${t(`days.${day}`)}`}>
      <div className="flex flex-col gap-4 p-6">
        <h2 className="type-title-l">{t("weekRowLabel", { number: week })} · {t(`days.${day}`)}</h2>
        <TextField size="dense" leadingIcon="search" aria-label={t("pickTemplate")} placeholder={t("searchTemplatePlaceholder")} value={search} onChange={(e) => setSearch(e.target.value)} />
        <div className="flex flex-col gap-1.5 max-h-[200px] overflow-y-auto">
          {filtered.length === 0 ? (
            <p className="type-body-s text-center py-3" style={{ color: "var(--text-3)" }}>{t("noTemplatesFound")}</p>
          ) : (
            filtered.map((tpl) => {
              const selected = tpl.id === templateId;
              return (
                <button
                  key={tpl.id}
                  type="button"
                  data-testid="program-slot-template-row"
                  onClick={() => setTemplateId(tpl.id)}
                  aria-pressed={selected}
                  className="lifey-button flex items-center gap-3 px-3 py-2.5 text-left"
                  style={{ borderRadius: "var(--r-control)", background: selected ? "var(--primary-tint)" : "var(--nested)", boxShadow: selected ? "inset 0 0 0 2px var(--primary)" : undefined }}
                >
                  <Icon name="fitness_center" size={20} fill={1} color="var(--role)" />
                  <span className="flex-1 min-w-0 truncate" style={{ fontWeight: 700 }}>{tpl.name}</span>
                  {selected && <Icon name="check_circle" size={20} fill={1} color="var(--primary)" />}
                </button>
              );
            })
          )}
        </div>
        <TimeField label={t("timeOfDay")} value={timeOfDay} onChange={setTimeOfDay} quickTimes={["07:00", "17:30", "18:00"]} />
        <TextArea label={t("note")} placeholder={t("notePlaceholder")} value={note} rows={2} maxLength={500} onChange={(e) => setNote(e.target.value)} />
        <div className="flex flex-wrap justify-end gap-2 pt-1">
          {existing && <Button variant="ghost" onClick={onClear}>{t("clearSlot")}</Button>}
          <Button variant="secondary" onClick={onClose}>{t("cancel")}</Button>
          <Button disabled={templateId == null} data-testid="program-slot-save" onClick={() => onSave({ weekNumber: week, dayOfWeek: day, templateId: templateId as number, timeOfDay: timeOfDay || null, note: note || null })}>
            {t("save")}
          </Button>
        </div>
      </div>
    </Modal>
  );
}

/**
 * "Hét másolása" (W8.5): pick the source week and the week(s) it should overwrite. Weeks that already hold workouts are
 * marked, so nobody overwrites one by accident; the copy itself is the tested `copyWeek`.
 */
function CopyWeekDialog({ weeksCount, workouts, onApply, onClose }: { weeksCount: number; workouts: ProgramWorkoutRequest[]; onApply: (source: number, targets: number[]) => void; onClose: () => void }) {
  const t = useTranslations("admin.programs");
  const weeks = Array.from({ length: weeksCount }, (_, i) => i + 1);
  const [source, setSource] = useState(1);
  const [targets, setTargets] = useState<number[]>([]);
  const others = weeks.filter((w) => w !== source);
  const filled = (w: number) => workouts.some((x) => x.weekNumber === w);
  const toggle = (w: number) => setTargets((prev) => (prev.includes(w) ? prev.filter((x) => x !== w) : [...prev, w]));
  const chosen = targets.filter((w) => w !== source);

  return (
    <Modal open onClose={onClose} width={480} aria-label={t("copyWeekAction")}>
      <div className="flex flex-col gap-4 p-6">
        <h2 className="type-title-l">{t("copyWeekAction")}</h2>
        <SelectField label={t("copyFrom")} value={source} onChange={(e) => { setSource(Number(e.target.value)); setTargets([]); }}>
          {weeks.map((w) => <option key={w} value={w}>{t("weekRowLabel", { number: w })} · {t("workoutsInWeek", { count: workouts.filter((x) => x.weekNumber === w).length })}</option>)}
        </SelectField>
        <fieldset className="flex flex-col gap-2">
          <legend className="type-body-s mb-1" style={{ color: "var(--text-2)", fontWeight: 700 }}>{t("copyTo")}</legend>
          {others.map((w) => (
            <Checkbox key={w} checked={targets.includes(w)} onChange={() => toggle(w)} label={`${t("weekRowLabel", { number: w })}${filled(w) ? ` · ${t("willOverwrite")}` : ""}`} />
          ))}
          <button type="button" className="self-start type-body-s" style={{ color: "var(--primary)", fontWeight: 700 }} onClick={() => setTargets(others)}>{t("allOtherWeeks")}</button>
        </fieldset>
        <div className="flex justify-end gap-2 pt-1">
          <Button variant="secondary" onClick={onClose}>{t("cancel")}</Button>
          <Button disabled={chosen.length === 0} onClick={() => onApply(source, chosen)} data-testid="program-copy-week-apply">{t("copyApply")}</Button>
        </div>
      </div>
    </Modal>
  );
}
