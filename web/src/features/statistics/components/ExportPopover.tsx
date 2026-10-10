"use client";

import { useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { Button, Checkbox, Icon, IconButton, Popover } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import { useToast } from "@/lib/hooks/useToast";
import {
  buildExport,
  downloadCsvFiles,
  EXPORT_SETS,
  exportRange,
  type ExportLabels,
  type ExportPeriodChoice,
  type ExportSet,
} from "../exportCsv";
import type { PeriodRange, StatsPeriod } from "../period";
import type { RawData } from "../types";

const PERIOD_CHOICES: ExportPeriodChoice[] = ["viewed", "last30", "all"];
// The canvas ticks the first three; water and steps are the extra.
const DEFAULT_SETS: ExportSet[] = ["meals", "weight", "workouts"];

export interface ExportControlProps {
  raw: RawData;
  /** The period on screen — what the first choice exports. */
  viewed: PeriodRange;
  period: StatsPeriod;
  /** The viewed period contains today ("Ez a hét") rather than being an earlier one. */
  isCurrent: boolean;
  /** "szept. 14–20." — names the first choice when the period on screen is not the current one. */
  periodLabel: string;
  /** A round icon button instead of the labelled one — the phone header (W5-D). */
  iconOnly?: boolean;
}

/**
 * The statistics export (W5.8, W5-C): "Exportálás" opens a popover — **Időszak** (the viewed period · 30 nap · Minden
 * adat), the data sets as checkboxes, "CSV · UTF-8" and **Letöltés**. The CSVs are built in the browser (`exportCsv.ts`),
 * one per ticked set and downloaded in sequence, and a toast then names the file(s): "lifey-2026-09-21_27.csv letöltve".
 */
export function ExportControl({ raw, viewed, period, isCurrent, periodLabel, iconOnly = false }: ExportControlProps) {
  const t = useTranslations("statistics");
  const fmt = useFormat();
  const toast = useToast((s) => s.show);
  const anchorRef = useRef<HTMLSpanElement>(null);
  const [open, setOpen] = useState(false);
  const [choice, setChoice] = useState<ExportPeriodChoice>("viewed");
  const [sets, setSets] = useState<ExportSet[]>(DEFAULT_SETS);
  const [busy, setBusy] = useState(false);

  const toggle = (set: ExportSet, on: boolean) => setSets((cur) => (on ? [...cur, set] : cur.filter((s) => s !== set)));

  const choiceLabel = (c: ExportPeriodChoice) => {
    if (c === "last30") return t("export_last30");
    if (c === "all") return t("export_all");
    return isCurrent ? t(`export_this_${period}`) : periodLabel;
  };

  async function download() {
    if (sets.length === 0 || busy) return;
    setBusy(true);
    try {
      const labels: ExportLabels = {
        headers: {
          meals: ["date", "time", "meal", "food", "grams", "kcal", "protein", "carbs", "fat", "fiber", "sugar"].map((k) => t(`export_col_${k}`)),
          weight: ["date", "weight"].map((k) => t(`export_col_${k}`)),
          workouts: ["date", "time", "kind", "activity", "exercise", "reps", "weightKg", "volume", "distance", "minutes"].map((k) => t(`export_col_${k}`)),
          waterSteps: ["date", "water", "steps"].map((k) => t(`export_col_${k}`)),
        },
        mealType: (type) => fmt.mealTypeLabel(type),
        activity: (type) => fmt.activityLabel(type),
        sessionKind: (kind) => t(kind === "CARDIO" ? "kind_CARDIO" : "kind_STRENGTH"),
      };
      const range = exportRange(choice, viewed, raw, new Date());
      const files = buildExport(sets, raw, range, fmt.locale, labels);
      await downloadCsvFiles(files);
      toast(
        files.length === 1
          ? t("exportDone", { name: files[0].name })
          : t("exportDoneMany", { count: files.length, names: files.map((f) => f.name).join(", ") }),
        "success",
      );
      setOpen(false);
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <span ref={anchorRef} className="inline-flex">
        {iconOnly ? (
          <IconButton
            icon="download"
            label={t("export")}
            size={44}
            style={{ background: "var(--control)", borderRadius: "var(--r-pill)" }}
            onClick={() => setOpen((v) => !v)}
            aria-haspopup="dialog"
            aria-expanded={open}
          />
        ) : (
          <Button variant="secondary" onClick={() => setOpen((v) => !v)} aria-haspopup="dialog" aria-expanded={open}>
            <Icon name="download" size={20} />
            {t("export")}
          </Button>
        )}
      </span>

      <Popover open={open} onClose={() => setOpen(false)} anchorRef={anchorRef} width={360}>
        <div role="dialog" aria-label={t("exportTitle")} className="flex flex-col gap-4 p-5" data-testid="export-popover">
          <h2 className="type-title-s" style={{ fontSize: 18, fontWeight: 800 }}>
            {t("exportTitle")}
          </h2>

          <div className="flex flex-col gap-2" role="radiogroup" aria-label={t("exportPeriod")}>
            <span className="type-body-s" style={{ fontWeight: 600 }}>
              {t("exportPeriod")}
            </span>
            <div className="flex flex-wrap gap-1.5">
              {PERIOD_CHOICES.map((c) => {
                const active = choice === c;
                return (
                  <button
                    key={c}
                    type="button"
                    role="radio"
                    aria-checked={active}
                    onClick={() => setChoice(c)}
                    className="lifey-button rounded-[var(--r-pill)] px-3 h-9 type-body-s whitespace-nowrap"
                    style={{
                      background: active ? "var(--primary)" : "var(--nested)",
                      color: active ? "var(--on-primary)" : "var(--text-2)",
                      fontWeight: active ? 700 : 600,
                    }}
                  >
                    {choiceLabel(c)}
                  </button>
                );
              })}
            </div>
          </div>

          <fieldset className="flex flex-col rounded-[var(--r-control)] py-1" style={{ background: "var(--nested)" }}>
            <legend className="sr-only">{t("exportSets")}</legend>
            {EXPORT_SETS.map((set) => (
              <div key={set} className="px-3.5 py-2.5">
                <Checkbox checked={sets.includes(set)} onChange={(on) => toggle(set, on)} label={t(`export_set_${set}`)} />
              </div>
            ))}
          </fieldset>

          <div className="flex items-center justify-between gap-3">
            <span className="type-body-s" style={{ color: "var(--text-2)" }}>
              {t("exportFormat")}
            </span>
            <Button onClick={download} disabled={sets.length === 0 || busy}>
              {t("exportDownload")}
            </Button>
          </div>
        </div>
      </Popover>
    </>
  );
}
