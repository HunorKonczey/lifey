"use client";

import { useTranslations } from "next-intl";
import { Card, Icon } from "@/components/ds";
import { DAYS_OF_WEEK, findSlot } from "../program";
import type { DayOfWeek, ProgramWorkoutRequest } from "../types";

interface ProgramWeekGridProps {
  weeksCount: number;
  workouts: ProgramWorkoutRequest[];
  templateName: (id: number) => string;
  templateExercises: (id: number) => number | null;
  /** True while a template is picked: an empty cell then reads "Ide: Láb + core" and places on click. */
  placing: string | null;
  onCell: (week: number, day: DayOfWeek) => void;
  onDuplicateBelow: (week: number) => void;
  onCopyToAll: (week: number) => void;
}

/**
 * The program as weeks × days (W8-B): `88px | 7 × 1fr`, weeks as rows labelled "1. hét · 3 edzés", days as columns.
 * A filled cell is a workout tile (primary tint, a 3 px bar, the name and "6 gyakorlat"), an empty one a dashed
 * hairline. Each cell is a button, so the grid works from the keyboard: Tab to a cell, Enter places the picked
 * template or opens the slot.
 */
export function ProgramWeekGrid({ weeksCount, workouts, templateName, templateExercises, placing, onCell, onDuplicateBelow, onCopyToAll }: ProgramWeekGridProps) {
  const t = useTranslations("admin.programs");
  const weeks = Array.from({ length: weeksCount }, (_, i) => i + 1);

  return (
    <Card variant="card" className="overflow-x-auto" data-testid="program-week-grid">
      <div className="grid gap-2" style={{ gridTemplateColumns: "84px repeat(7, minmax(88px, 1fr))", minWidth: 720 }} role="grid" aria-label={t("gridAria")}>
        <div role="presentation" />
        {DAYS_OF_WEEK.map((day) => (
          <div key={day} role="columnheader" className="type-body-s text-center py-1" style={{ color: "var(--text-2)", fontWeight: 700 }}>
            {t(`days.${day}`)}
          </div>
        ))}
        {weeks.map((week) => {
          const count = workouts.filter((w) => w.weekNumber === week).length;
          return (
            <div key={week} role="row" className="contents">
              <div role="rowheader" className="flex flex-col justify-center gap-0.5 pr-1">
                <span style={{ fontSize: 13, fontWeight: 800 }}>{t("weekRowLabel", { number: week })}</span>
                <span className="type-body-s" style={{ color: "var(--text-2)" }}>{t("workoutsInWeek", { count })}</span>
                <span className="flex flex-col">
                  {week < weeksCount && (
                    <button type="button" onClick={() => onDuplicateBelow(week)} className="text-left" style={{ fontSize: 11, fontWeight: 600, color: "var(--primary)" }}>
                      {t("duplicateWeekBelow")}
                    </button>
                  )}
                  {weeksCount > 1 && (
                    <button type="button" onClick={() => onCopyToAll(week)} className="text-left" style={{ fontSize: 11, fontWeight: 600, color: "var(--primary)" }}>
                      {t("copyWeekToAll")}
                    </button>
                  )}
                </span>
              </div>
              {DAYS_OF_WEEK.map((day) => {
                const slot = findSlot(workouts, week, day);
                const exercises = slot ? templateExercises(slot.templateId) : null;
                return (
                  <button
                    key={day}
                    type="button"
                    role="gridcell"
                    data-testid={`program-cell-${week}-${day}`}
                    onClick={() => onCell(week, day)}
                    aria-label={slot ? `${t("weekRowLabel", { number: week })}, ${t(`days.${day}`)}: ${templateName(slot.templateId)}` : `${t("weekRowLabel", { number: week })}, ${t(`days.${day}`)}: ${placing ? t("placeHere", { name: placing }) : t("emptySlot")}`}
                    className="lifey-button relative flex min-h-[72px] flex-col items-start justify-center gap-0.5 py-2 pl-3.5 pr-2 text-left"
                    style={
                      slot
                        ? { borderRadius: 12, background: "color-mix(in srgb, var(--primary) 10%, transparent)" }
                        : { borderRadius: 12, boxShadow: "inset 0 0 0 1.5px var(--hairline)", borderStyle: "dashed" }
                    }
                  >
                    {slot ? (
                      <>
                        <span aria-hidden className="absolute left-0 top-2 bottom-2" style={{ width: 3, borderRadius: 2, background: "var(--primary)" }} />
                        <span className="w-full truncate" style={{ fontSize: 13, fontWeight: 700 }}>{templateName(slot.templateId)}</span>
                        <span className="type-body-s" style={{ color: "var(--text-2)" }}>
                          {exercises != null ? t("exerciseCount", { count: exercises }) : ""}
                          {slot.timeOfDay ? `${exercises != null ? " · " : ""}${slot.timeOfDay.slice(0, 5)}` : ""}
                        </span>
                      </>
                    ) : placing ? (
                      <Icon name="add" size={20} color="var(--primary)" />
                    ) : (
                      <span className="type-body-s" style={{ color: "var(--text-3)" }}>{t("emptySlot")}</span>
                    )}
                  </button>
                );
              })}
            </div>
          );
        })}
      </div>
    </Card>
  );
}
