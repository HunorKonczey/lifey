"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { format, subDays, eachDayOfInterval } from "date-fns";
import { stepsApi } from "@/features/steps/api";
import { settingsApi } from "@/features/settings/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useDateStore } from "@/lib/hooks/useDateStore";
import { useToast } from "@/lib/hooks/useToast";
import { Skeleton } from "@/components/status/Skeleton";
import { ErrorState } from "@/components/status/ErrorState";

export default function StepsPage() {
  const t = useTranslations("steps");
  const nav = useTranslations("nav");
  const common = useTranslations("common");
  const { date } = useDateStore();
  const queryClient = useQueryClient();
  const { show } = useToast();
  const dateStr = format(date, "yyyy-MM-dd");
  const [editing, setEditing] = useState(false);
  const [value, setValue] = useState("");

  const stepsQ = useQuery({ queryKey: queryKeys.steps.all(), queryFn: stepsApi.list });
  const settingsQ = useQuery({ queryKey: queryKeys.settings.all(), queryFn: settingsApi.get, staleTime: 5 * 60_000 });

  const byDate = new Map((stepsQ.data ?? []).map((s) => [s.date, s]));
  const todayEntry = byDate.get(dateStr) ?? null;
  const goal = settingsQ.data?.dailyStepGoal ?? 10000;

  const saveMutation = useMutation({
    mutationFn: () => {
      const steps = Math.max(0, Number(value));
      return todayEntry
        ? stepsApi.update(todayEntry.id, { date: dateStr, steps })
        : stepsApi.create({ date: dateStr, steps });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.steps.all() });
      show(t("saved"), "success");
      setEditing(false); setValue("");
    },
    onError: () => show(t("saveFailed"), "error"),
  });

  // Last 7 days ending on selected date
  const days = eachDayOfInterval({ start: subDays(date, 6), end: date });
  const bars = days.map((d) => {
    const key = format(d, "yyyy-MM-dd");
    const steps = byDate.get(key)?.steps ?? 0;
    return { key, label: format(d, "EEE"), steps, isSelected: key === dateStr };
  });
  const maxSteps = Math.max(goal, ...bars.map((b) => b.steps), 1);

  if (stepsQ.isLoading) return <Skeleton variant="card" className="h-80" />;
  if (stepsQ.isError) return <ErrorState onRetry={() => stepsQ.refetch()} />;

  return (
    <div className="flex flex-col gap-5">
      <div className="flex items-center gap-2">
        <span className="material-symbols-rounded text-2xl" style={{ color: "var(--metric-steps)" }}>directions_walk</span>
        <h1 className="text-xl font-bold">{nav("steps")}</h1>
      </div>

      {/* Today value */}
      <div className="rounded-[var(--r-lg)] p-5" style={{ background: "var(--surface)" }}>
        <div className="flex items-start justify-between">
          <div>
            <p className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>
              {dateStr === format(new Date(), "yyyy-MM-dd") ? common("today") : format(date, "MMM d")}
            </p>
            <p className="text-4xl font-extrabold tabular" style={{ color: "var(--on-surface)" }}>
              {(todayEntry?.steps ?? 0).toLocaleString()}
            </p>
            <p className="text-xs tabular mt-1" style={{ color: "var(--muted)" }}>{t("goal", { value: goal.toLocaleString() })}</p>
          </div>
          {!editing ? (
            <button onClick={() => { setEditing(true); setValue(String(todayEntry?.steps ?? "")); }}
              className="flex items-center gap-1 px-4 h-9 rounded-[var(--r-input)] font-semibold text-sm"
              style={{ background: "var(--surface-highest)", color: "var(--on-surface)" }}>
              <span className="material-symbols-rounded text-lg">edit</span> {common("edit")}
            </button>
          ) : (
            <div className="flex items-center gap-2">
              <input type="number" min={0} value={value} autoFocus onChange={(e) => setValue(e.target.value)}
                className="px-3 h-9 w-28 rounded-[var(--r-input)] outline-none text-sm tabular"
                style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
              <button onClick={() => saveMutation.mutate()} disabled={saveMutation.isPending}
                className="h-9 px-4 rounded-[var(--r-input)] font-semibold text-sm"
                style={{ background: "var(--primary)", color: "#1E1F18" }}>{common("save")}</button>
              <button onClick={() => setEditing(false)} className="h-9 px-3 text-sm" style={{ color: "var(--on-surface-variant)" }}>{common("cancel")}</button>
            </div>
          )}
        </div>

        {/* progress to goal */}
        <div className="h-2 rounded-[var(--r-pill)] overflow-hidden mt-4" style={{ background: "var(--surface-highest)" }}>
          <div className="h-full rounded-[var(--r-pill)] transition-all"
            style={{
              width: `${Math.min((todayEntry?.steps ?? 0) / goal, 1) * 100}%`,
              background: (todayEntry?.steps ?? 0) >= goal ? "var(--goal-positive)" : "var(--metric-steps)",
            }} />
        </div>
      </div>

      {/* 7-day bar chart */}
      <div className="rounded-[var(--r-card)] p-5" style={{ background: "var(--surface)" }}>
        <p className="text-sm font-bold mb-4">{t("last7Days")}</p>
        <div className="flex items-end justify-between gap-2" style={{ height: 160 }}>
          {bars.map((b) => {
            const reached = b.steps >= goal;
            return (
              <div key={b.key} className="flex-1 flex flex-col items-center gap-2 h-full justify-end">
                <span className="text-xs tabular font-semibold" style={{ color: "var(--on-surface-variant)" }}>
                  {b.steps > 0 ? (b.steps >= 1000 ? `${(b.steps / 1000).toFixed(1)}k` : b.steps) : ""}
                </span>
                <div className="w-full rounded-t-[var(--r-sm)] transition-all duration-[var(--dur-base)]"
                  style={{
                    height: `${(b.steps / maxSteps) * 100}%`,
                    minHeight: b.steps > 0 ? 4 : 0,
                    background: b.isSelected
                      ? "var(--metric-steps)"
                      : reached ? "var(--goal-positive)" : "color-mix(in srgb, var(--metric-steps) 40%, transparent)",
                  }} />
                <span className="text-xs" style={{ color: b.isSelected ? "var(--on-surface)" : "var(--muted)" }}>{b.label}</span>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
