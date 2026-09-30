"use client";

import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { Button, Card, Icon, RecordChip } from "@/components/ds";
import { ConfirmModal } from "@/components/ds/overlay/ConfirmModal";
import { RowMenuButton } from "@/components/ds/RowMenuButton";
import { queryKeys } from "@/lib/api/queryKeys";
import { formatDate, formatNumber, intlLocale, useFormat } from "@/lib/i18n/format";
import { useToast } from "@/lib/hooks/useToast";
import { workoutSessionApi } from "../api";
import { summarizeSession, type SetLine } from "../sessionSummary";
import { formatHoursMinutes, formatKg } from "../weekLabels";
import type { WorkoutSessionResponse } from "../types";

/** "sessionTitle": the template name, else the exercises, else the generic fallback — same rule as the list row. */
export function sessionTitle(session: WorkoutSessionResponse, fallback: string): string {
  return session.templateName ?? (session.exercises.map((e) => e.exerciseName).join(", ") || fallback);
}

/** "péntek, szept. 26. · 17:40–18:32" — the panel's overline. */
export function sessionWhenLabel(session: WorkoutSessionResponse, locale: "en" | "hu"): string {
  const tag = intlLocale(locale);
  const start = new Date(session.startedAt);
  // "péntek, szept. 25." — built from parts: Intl puts the weekday after the date in Hungarian.
  const day = `${new Intl.DateTimeFormat(tag, { weekday: "long" }).format(start)}, ${formatDate(start, "day", locale)}`;
  const time = new Intl.DateTimeFormat(tag, { hour: "2-digit", minute: "2-digit", hour12: false });
  const end = session.finishedAt ? `–${time.format(new Date(session.finishedAt))}` : "";
  return `${day} · ${time.format(start)}${end}`;
}

/**
 * The closed-session summary (W3.4, W3-A right column / drawer): when, name and "⋯", three stats, the record
 * hero, the best set per exercise with ↑ when it beat last time, and the two actions — "Ismétlés ma" starts a
 * session from the same template, "Szerkesztés" is the only way into the editor. `bare` drops the header for
 * the drawer, which has its own.
 */
export function SessionSummary({
  session,
  history,
  bare = false,
  starting = false,
  onRepeat,
  onEdit,
  onDeleted,
}: {
  session: WorkoutSessionResponse;
  history: WorkoutSessionResponse[];
  bare?: boolean;
  starting?: boolean;
  onRepeat: () => void;
  onEdit: () => void;
  onDeleted: () => void;
}) {
  const t = useTranslations("workouts");
  const d = useTranslations("dashboard");
  const common = useTranslations("common");
  const { locale } = useFormat();
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [confirmingDelete, setConfirmingDelete] = useState(false);

  const summary = summarizeSession(session, history);
  const topRecord = summary.records[0];
  const weight = (n: number) => formatNumber(n, locale, 2);
  const setText = (s: SetLine) => `${weight(s.weight)} kg × ${s.reps}`;

  const deleteMutation = useMutation({
    mutationFn: () => workoutSessionApi.delete(session.id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.workoutSessions.all() });
      show(t("sessionDeleted"), "success");
      onDeleted();
    },
    onError: () => show(t("deleteFailed"), "error"),
  });

  const title = sessionTitle(session, d("workoutFallback"));
  const menu = (
    <RowMenuButton
      label={t("moreActions")}
      items={[{ label: t("deleteSession"), icon: "delete", destructive: true, onSelect: () => setConfirmingDelete(true) }]}
    />
  );

  return (
    <div className="flex flex-col gap-5">
      {!bare && (
        <header className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <p className="type-body-s" style={{ color: "var(--text-3)" }}>
              {sessionWhenLabel(session, locale)}
            </p>
            <h2 className="type-title truncate">{title}</h2>
          </div>
          {menu}
        </header>
      )}
      {bare && <div className="-mt-2 flex justify-end">{menu}</div>}

      {session.trainerComment && (
        <Card variant="nested">
          <p className="type-label" style={{ color: "var(--text-3)" }}>
            {t("trainerComment")}
          </p>
          <p className="type-body mt-1">{session.trainerComment}</p>
        </Card>
      )}

      <dl className="grid grid-cols-3 gap-3">
        <Stat label={t("summaryTime")} value={summary.seconds != null && summary.seconds >= 30 ? formatHoursMinutes(summary.seconds, locale) : "—"} />
        <Stat label={t("summaryVolume")} value={summary.volumeKg > 0 ? formatKg(summary.volumeKg, locale) : "—"} />
        <Stat label="RPE" value={session.rpe != null ? t("rpeOutOf", { rpe: session.rpe }) : "—"} />
      </dl>

      {topRecord && (
        <div
          className="flex flex-col gap-1 rounded-[var(--r-card)] p-4"
          style={{ background: "color-mix(in srgb, var(--record) var(--chip-tint), transparent)" }}
        >
          <RecordChip label={t("newRecord")} />
          <p className="type-body" style={{ fontWeight: 700 }}>
            {topRecord.exerciseName} — {setText(topRecord.set)}
          </p>
          {topRecord.previous && (
            <p className="type-body-s" style={{ color: "var(--text-2)" }}>
              {t("recordBefore", { value: setText(topRecord.previous) })}
            </p>
          )}
        </div>
      )}

      <section className="flex flex-col gap-1">
        {summary.exercises.length === 0 ? (
          <p className="type-body-s" style={{ color: "var(--text-3)" }}>
            {t("summaryNoSets")}
          </p>
        ) : (
          <ul className="flex flex-col divide-y" style={{ borderColor: "var(--hairline)" }}>
            {summary.exercises.map((ex) => {
              const sameReps = ex.sets.every((s) => s.reps === ex.sets[0].reps);
              const line = sameReps
                ? `${ex.sets.map((s) => weight(s.weight)).join(" / ")} kg × ${ex.sets[0].reps}`
                : `${ex.sets.map((s) => `${weight(s.weight)}×${s.reps}`).join(" / ")} kg`;
              return (
                <li key={ex.exerciseId} className="flex items-start justify-between gap-3 py-3" style={{ borderColor: "var(--hairline)" }}>
                  <div className="min-w-0">
                    <p className="type-body" style={{ fontWeight: 700 }}>
                      {ex.exerciseName}
                    </p>
                    <p className="type-body-s tabular" style={{ color: "var(--text-2)" }}>
                      {t("summarySets", { count: ex.sets.length })} · {line}
                    </p>
                  </div>
                  <p className="type-body tabular flex flex-none items-center gap-1" style={{ fontWeight: 700 }}>
                    {setText(ex.best)}
                    {ex.improved && <Icon name="arrow_upward" size={16} color="var(--improvement)" label={t("improvedAria")} />}
                  </p>
                </li>
              );
            })}
          </ul>
        )}
      </section>

      <div className="flex flex-wrap gap-2">
        <Button variant="tonal" onClick={onRepeat} disabled={starting}>
          <Icon name="replay" size={20} />
          {t("repeatToday")}
        </Button>
        <Button variant="secondary" onClick={onEdit}>
          <Icon name="edit" size={20} />
          {t("editSession")}
        </Button>
      </div>

      <ConfirmModal
        open={confirmingDelete}
        onClose={() => setConfirmingDelete(false)}
        onConfirm={() => {
          setConfirmingDelete(false);
          deleteMutation.mutate();
        }}
        icon="delete"
        title={t("deleteSessionTitle")}
        body={t("deleteSessionBody")}
        cancelLabel={common("cancel")}
        confirmLabel={common("delete")}
      />
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-[var(--r-card)] p-3" style={{ background: "var(--nested)" }}>
      <dt className="type-label" style={{ color: "var(--text-3)" }}>
        {label}
      </dt>
      <dd className="type-body tabular mt-0.5" style={{ fontWeight: 800 }}>
        {value}
      </dd>
    </div>
  );
}
