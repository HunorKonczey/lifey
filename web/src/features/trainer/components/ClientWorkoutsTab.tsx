"use client";

import { useEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { format } from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { trainerApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { Skeleton } from "@/components/status/Skeleton";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { useLocale } from "@/lib/hooks/useLocale";

const DATE_LOCALES = { en: enUS, hu } as const;

interface ClientWorkoutsTabProps {
  clientId: number;
  /* Set when arriving from the Schedule tab's "jump to session" — expands and scrolls to it once loaded. */
  focusSessionId?: number | null;
  onFocusHandled?: () => void;
}

export function ClientWorkoutsTab({ clientId, focusSessionId, onFocusHandled }: ClientWorkoutsTabProps) {
  const t = useTranslations("admin.clientDetail");
  const common = useTranslations("common");
  const dateLocale = DATE_LOCALES[useLocale((s) => s.locale)];
  const [page, setPage] = useState(0);
  const [expandedId, setExpandedId] = useState<number | null>(null);
  const rowRefs = useRef<Record<number, HTMLDivElement | null>>({});

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.trainerClientData.sessions(clientId, page, 15),
    queryFn: () => trainerApi.clientWorkoutSessions(clientId, page, 15),
  });

  // Adjusted during render (React's blessed pattern, see DatePicker's prevValue)
  // rather than in an effect, since it's a plain state derivation, not a side effect.
  const [consumedFocusSessionId, setConsumedFocusSessionId] = useState<number | null | undefined>(undefined);
  const focusTarget = focusSessionId != null && data?.content.some((s) => s.id === focusSessionId)
    ? focusSessionId
    : null;
  if (focusTarget != null && focusTarget !== consumedFocusSessionId) {
    setConsumedFocusSessionId(focusTarget);
    setExpandedId(focusTarget);
  }

  useEffect(() => {
    if (focusTarget == null) return;
    rowRefs.current[focusTarget]?.scrollIntoView({ behavior: "smooth", block: "center" });
    onFocusHandled?.();
  }, [focusTarget, onFocusHandled]);

  if (isLoading) return <Skeleton variant="table" />;
  if (isError) return <ErrorState onRetry={refetch} />;
  if (!data || data.content.length === 0) {
    return <EmptyState icon="fitness_center" title={t("noSessions")} />;
  }

  return (
    <div className="flex flex-col gap-3.5">
      <div className="flex flex-col gap-2">
        {data.content.map((s) => {
          const expanded = expandedId === s.id;
          const volume = s.sets.reduce((sum, set) => sum + set.reps * set.weight, 0);
          const durationMin = s.finishedAt
            ? Math.round((new Date(s.finishedAt).getTime() - new Date(s.startedAt).getTime()) / 60000)
            : null;
          return (
            <div
              key={s.id}
              ref={(el) => { rowRefs.current[s.id] = el; }}
              className="rounded-[var(--r-card)]"
              style={{ background: "var(--surface)", outline: focusSessionId === s.id ? "2px solid var(--tertiary)" : "none" }}
            >
              <button
                onClick={() => setExpandedId(expanded ? null : s.id)}
                className="w-full flex items-center gap-3.5 px-4 py-3.5 text-left"
              >
                <span className="material-symbols-rounded text-xl" style={{ color: "var(--on-surface-variant)" }}>
                  {expanded ? "expand_more" : "chevron_right"}
                </span>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-bold" style={{ color: "var(--on-surface)" }}>
                    {format(new Date(s.startedAt), "yyyy. MMM d. HH:mm", { locale: dateLocale })}
                  </p>
                  <p className="text-[11.5px] mt-0.5" style={{ color: "var(--on-surface-variant)" }}>
                    {t("sessionMeta", {
                      duration: durationMin ?? "—",
                      count: s.exercises.length,
                      volume: Math.round(volume).toLocaleString(),
                    })}
                  </p>
                </div>
                {s.rpe != null && (
                  <span
                    className="flex items-center gap-1.5 rounded-[var(--r-pill)] text-[11px] font-extrabold px-2.5 py-1.5 shrink-0"
                    style={{
                      background: "color-mix(in srgb, var(--secondary) 18%, transparent)",
                      color: "var(--secondary)",
                    }}
                  >
                    <span className="material-symbols-rounded text-sm">speed</span>
                    {t("sessionRpe", { rpe: s.rpe })}
                  </span>
                )}
                {s.templateName && (
                  <span
                    className="flex items-center gap-1.5 rounded-[var(--r-pill)] text-[11px] font-extrabold px-2.5 py-1.5 shrink-0"
                    style={{ background: "var(--tertiary-container)", color: "var(--on-tertiary-container)" }}
                  >
                    <span className="material-symbols-rounded text-sm">assignment</span>
                    {s.templateName}
                  </span>
                )}
              </button>
              {expanded && (
                <div className="px-4 pb-4 flex flex-col gap-2">
                  {s.feedbackNote && (
                    <p
                      className="text-[12.5px] italic px-3 py-2 rounded-2xl"
                      style={{ background: "var(--surface-container)", color: "var(--on-surface-variant)" }}
                    >
                      “{s.feedbackNote}”
                    </p>
                  )}
                  {s.exercises.map((ex) => {
                    const exerciseSets = s.sets.filter((set) => set.exerciseId === ex.exerciseId);
                    return (
                      <div key={ex.exerciseId} className="rounded-2xl p-3" style={{ background: "var(--surface-container)" }}>
                        <p className="text-[13px] font-bold mb-1.5" style={{ color: "var(--on-surface)" }}>
                          {ex.exerciseName}
                        </p>
                        <div className="flex flex-wrap gap-2">
                          {exerciseSets.map((set, i) => (
                            <span
                              key={i}
                              className="text-xs tabular font-semibold px-2.5 py-1 rounded-lg"
                              style={{ background: "var(--surface-high)", color: "var(--on-surface-variant)" }}
                            >
                              {set.reps} × {set.weight} kg
                            </span>
                          ))}
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          );
        })}
      </div>

      <div className="flex items-center justify-center gap-1.5">
        <button
          onClick={() => setPage((p) => Math.max(0, p - 1))}
          disabled={data.number === 0}
          className="p-1.5 disabled:opacity-30"
          style={{ color: "var(--on-surface-variant)" }}
          aria-label={common("previousPage")}
        >
          <span className="material-symbols-rounded text-xl">chevron_left</span>
        </button>
        <span className="text-xs font-bold px-2" style={{ color: "var(--on-surface-variant)" }}>
          {data.number + 1} / {Math.max(1, data.totalPages)}
        </span>
        <button
          onClick={() => setPage((p) => (data.last ? p : p + 1))}
          disabled={data.last}
          className="p-1.5 disabled:opacity-30"
          style={{ color: "var(--on-surface-variant)" }}
          aria-label={common("nextPage")}
        >
          <span className="material-symbols-rounded text-xl">chevron_right</span>
        </button>
      </div>
    </div>
  );
}
