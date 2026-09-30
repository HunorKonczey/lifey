"use client";

import { useTranslations } from "next-intl";
import { Button, Icon, IconButton } from "@/components/ds";
import type { LiveProgress } from "../../liveSession";
import { ElapsedTimer } from "./ElapsedTimer";

/**
 * The live logger's header (W3.6, W3-B): "×" (leave — asks when sets are unsaved), the workout's name with
 * "9 / 18 szett · 2 / 6 gyakorlat", the running time and the primary "Befejezés". A workout that is already
 * finished (reopened with "Szerkesztés") shows "Mentés" there instead — there is nothing left to finish.
 */
export function LiveHeader({
  name,
  progress,
  startedAt,
  finishedAt,
  pending,
  onLeave,
  onSave,
  onFinish,
}: {
  name: string;
  progress: LiveProgress;
  startedAt: string;
  finishedAt: string | null;
  pending: boolean;
  onLeave: () => void;
  onSave: () => void;
  onFinish: () => void;
}) {
  const t = useTranslations("workouts");
  const common = useTranslations("common");
  const finished = finishedAt != null;

  return (
    <header
      className="sticky top-0 z-20 flex flex-wrap items-center gap-x-4 gap-y-2 px-4 py-3 md:px-6"
      style={{ background: "var(--bg)", borderBottom: "1px solid var(--hairline)" }}
    >
      <IconButton icon="close" label={t("liveLeave")} onClick={onLeave} />
      <div className="min-w-0 flex-1">
        <h1 className="type-title-s truncate">{name}</h1>
        <p className="type-body-s tabular" style={{ color: "var(--text-2)" }}>
          {t("liveProgress", {
            doneSets: progress.doneSets,
            totalSets: progress.totalSets,
            doneExercises: progress.doneExercises,
            totalExercises: progress.totalExercises,
          })}
        </p>
      </div>
      <ElapsedTimer startedAt={startedAt} finishedAt={finishedAt} className="type-title-l" />
      <div className="flex items-center gap-2">
        {!finished && (
          <Button variant="secondary" onClick={onSave} disabled={pending}>
            {common("save")}
          </Button>
        )}
        <Button onClick={finished ? onSave : onFinish} disabled={pending}>
          <Icon name={finished ? "check" : "flag"} size={20} />
          {finished ? common("save") : t("finishShort")}
        </Button>
      </div>
    </header>
  );
}
