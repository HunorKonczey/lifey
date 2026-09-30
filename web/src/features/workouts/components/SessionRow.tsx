"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useLocale, useTranslations } from "next-intl";
import { Icon, IconButton, RecordChip } from "@/components/ds";
import { queryKeys } from "@/lib/api/queryKeys";
import { useFormat } from "@/lib/i18n/format";
import { useToast } from "@/lib/hooks/useToast";
import { workoutSessionApi } from "../api";
import { activityFamilyOf, activityTypeIcon } from "../activityType";
import { buildCardioSummaryLine } from "../cardioSummaryLine";
import { effectiveSeconds, sessionVolumeKg } from "../sessionGroups";
import { formatHoursMinutes, formatKg, formatKm } from "../weekLabels";
import type { WorkoutSessionResponse } from "../types";

/**
 * One row of the sessions list (W3.3, W3-A): grid `40 | 1fr | auto | 90` — a tinted icon (strength primary,
 * cardio heart), the name with its "🏆 PR" chip and a meta line, the main value ("6 240 kg", "5,2 km") and the
 * day ("P · szept. 26."). The selected row is `--nested` with a 3 px primary bar. Delete shows on hover / focus.
 */
export function SessionRow({
  session,
  records,
  selected = false,
  onOpen,
}: {
  session: WorkoutSessionResponse;
  /** Records this session set (personalRecords.recordsBySession) — 0 or missing: no chip. */
  records?: number;
  selected?: boolean;
  onOpen: () => void;
}) {
  const t = useTranslations("workouts");
  const ta = useTranslations("workouts.activityTypes");
  const d = useTranslations("dashboard");
  const intlLocale = useLocale();
  const { locale, date } = useFormat();
  const queryClient = useQueryClient();
  const { show } = useToast();

  const isCardio = session.sessionKind === "CARDIO";
  const exNames = session.exercises.map((e) => e.exerciseName).join(", ");
  const title = isCardio ? ta(session.activityType ?? "OTHER_CARDIO") : (session.templateName ?? (exNames || d("workoutFallback")));
  const ongoing = !session.finishedAt;

  const rawSeconds = effectiveSeconds(session);
  // Under a minute reads as "0 p" — show nothing instead.
  const seconds = rawSeconds != null && Math.round(rawSeconds / 60) > 0 ? rawSeconds : null;
  const volume = sessionVolumeKg(session);
  const meters = session.cardio?.distanceMeters ?? null;
  const showsDistance =
    isCardio && meters != null && meters > 0 && session.activityType != null && activityFamilyOf(session.activityType) !== "GAME";

  const meta = isCardio
    ? [buildCardioSummaryLine(session, t, intlLocale), session.averageHeartRate != null ? t("bpmAvg", { value: Math.round(session.averageHeartRate) }) : ""]
        .filter(Boolean)
        .join(" · ")
    : [
        session.exercises.length > 0 ? t("exercisesCount", { count: session.exercises.length }) : "",
        session.sets.length > 0 ? `${session.sets.length} ${t("sets").toLowerCase()}` : "",
        seconds != null && seconds > 0 ? formatHoursMinutes(seconds, locale) : "",
      ]
        .filter(Boolean)
        .join(" · ");

  const main = showsDistance
    ? formatKm(meters, locale)
    : !isCardio && volume > 0
      ? formatKg(volume, locale)
      : seconds != null && seconds > 0
        ? formatHoursMinutes(seconds, locale)
        : "";

  const tint = isCardio ? "var(--heart)" : "var(--primary)";
  const started = new Date(session.startedAt);

  const deleteMutation = useMutation({
    mutationFn: () => workoutSessionApi.delete(session.id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.workoutSessions.all() });
      show(t("sessionDeleted"), "success");
    },
    onError: () => show(t("deleteFailed"), "error"),
  });

  return (
    <div
      className="group relative flex items-center gap-1 pr-2"
      style={{ background: selected ? "var(--nested)" : undefined }}
      data-selected={selected || undefined}
    >
      {selected && <span aria-hidden className="absolute left-0 top-0 bottom-0" style={{ width: 3, background: "var(--primary)" }} />}
      <button
        type="button"
        onClick={onOpen}
        aria-current={selected || undefined}
        className="lifey-button grid min-w-0 flex-1 grid-cols-[40px_minmax(0,1fr)_auto] items-center gap-3 px-4 py-3 text-left md:grid-cols-[40px_minmax(0,1fr)_auto_90px]"
      >
        <span
          className="flex items-center justify-center"
          style={{
            width: 40,
            height: 40,
            borderRadius: 12,
            background: `color-mix(in srgb, ${tint} var(--chip-tint), transparent)`,
            color: tint,
          }}
        >
          <Icon name={isCardio ? activityTypeIcon(session.activityType) : "fitness_center"} size={22} />
        </span>
        <span className="min-w-0">
          <span className="flex items-center gap-2">
            <span className="type-body truncate" style={{ fontWeight: 700 }}>
              {title}
            </span>
            {ongoing && (
              <span className="type-label rounded-[var(--r-pill)] px-2 py-0.5" style={{ background: "color-mix(in srgb, var(--primary) var(--chip-tint), transparent)", color: "var(--primary)" }}>
                {t("inProgress")}
              </span>
            )}
            {records != null && records > 0 && <RecordChip label={t("prBadge")} />}
          </span>
          <span className="type-body-s tabular block truncate" style={{ color: "var(--text-2)" }}>
            <span className="md:hidden">{date(started, "weekday")} · {date(started, "day")}{meta ? " · " : ""}</span>
            {meta}
          </span>
        </span>
        <span className="type-body tabular text-right" style={{ fontWeight: 700 }}>
          {main}
        </span>
        <span className="type-body-s tabular hidden text-right md:block" style={{ color: "var(--text-3)" }}>
          {date(started, "weekday")} · {date(started, "day")}
        </span>
      </button>
      <span className="opacity-0 transition-opacity group-hover:opacity-100 group-focus-within:opacity-100 max-md:hidden">
        <IconButton icon="delete" label={t("deleteSessionAria")} size={32} onClick={() => deleteMutation.mutate()} disabled={deleteMutation.isPending} />
      </span>
    </div>
  );
}
