"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { format, subMonths, subYears } from "date-fns";
import { weightApi } from "@/features/weight/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { SegmentedControl } from "@/components/ui/SegmentedControl";
import { TimeSeriesChart, type SeriesPoint } from "@/components/data/TimeSeriesChartLazy";
import { Skeleton } from "@/components/status/Skeleton";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import type { WeightResponse } from "@/features/weight/types";

type Range = "1M" | "3M" | "1Y";

const RANGE_OPTIONS: { value: Range; label: string }[] = [
  { value: "1M", label: "1M" },
  { value: "3M", label: "3M" },
  { value: "1Y", label: "1Y" },
];

function rangeStart(range: Range): Date {
  const now = new Date();
  if (range === "1M") return subMonths(now, 1);
  if (range === "3M") return subMonths(now, 3);
  return subYears(now, 1);
}

export default function WeightPage() {
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [range, setRange] = useState<Range>("3M");
  const [adding, setAdding] = useState(false);
  const [newDate, setNewDate] = useState(format(new Date(), "yyyy-MM-dd"));
  const [newWeight, setNewWeight] = useState("");

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.weights.all(),
    queryFn: weightApi.list,
  });

  const createMutation = useMutation({
    mutationFn: () => weightApi.create({ date: newDate, weight: Number(newWeight) }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.weights.all() });
      show("Weight logged", "success");
      setAdding(false); setNewWeight("");
    },
    onError: () => show("Failed to save", "error"),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: number) => weightApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.weights.all() });
      show("Entry removed", "success");
    },
    onError: () => show("Failed to remove", "error"),
  });

  const sorted = (data ?? []).slice().sort((a, b) => a.date.localeCompare(b.date));
  const latest = sorted.at(-1) ?? null;
  const start = rangeStart(range);
  const chartData: SeriesPoint[] = sorted
    .filter((w) => new Date(w.date) >= start)
    .map((w) => ({ date: format(new Date(w.date), "MMM d"), value: w.weight }));

  // History newest-first with delta vs previous chronological entry
  const history = sorted.slice().reverse();

  return (
    <div className="flex flex-col gap-5">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="material-symbols-rounded text-2xl" style={{ color: "var(--metric-weight)" }}>monitor_weight</span>
          <h1 className="text-xl font-bold">Weight</h1>
        </div>
        <button onClick={() => setAdding((a) => !a)}
          className="flex items-center gap-1 px-4 h-9 rounded-[var(--r-input)] font-semibold text-sm"
          style={{ background: "var(--primary)", color: "#1E1F18" }}>
          <span className="material-symbols-rounded text-lg">add</span> New entry
        </button>
      </div>

      {adding && (
        <div className="flex flex-wrap items-end gap-3 p-4 rounded-[var(--r-card)]" style={{ background: "var(--surface)" }}>
          <div className="flex flex-col gap-1">
            <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>Date</label>
            <input type="date" value={newDate} max={format(new Date(), "yyyy-MM-dd")}
              onChange={(e) => setNewDate(e.target.value)}
              className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm tabular"
              style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
          </div>
          <div className="flex flex-col gap-1">
            <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>Weight (kg)</label>
            <input type="number" step="0.1" value={newWeight} autoFocus
              onChange={(e) => setNewWeight(e.target.value)}
              className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm tabular w-32"
              style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
          </div>
          <button onClick={() => createMutation.mutate()} disabled={!newWeight || createMutation.isPending}
            className="h-10 px-5 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-50"
            style={{ background: "var(--primary)", color: "#1E1F18" }}>
            Save
          </button>
        </div>
      )}

      {isLoading ? (
        <div className="flex gap-6">
          <Skeleton variant="chart" className="flex-1" />
          <Skeleton variant="card" className="w-[300px] h-72" />
        </div>
      ) : isError ? (
        <ErrorState onRetry={refetch} />
      ) : sorted.length === 0 ? (
        <EmptyState icon="monitor_weight" title="No weight entries"
          body="Log your first weight to start tracking your trend." />
      ) : (
        <div className="flex flex-col lg:flex-row gap-6">
          {/* Chart */}
          <div className="flex-1 min-w-0 rounded-[var(--r-lg)] p-5" style={{ background: "var(--surface)" }}>
            <div className="flex items-center justify-between mb-4">
              <div>
                <p className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>Current</p>
                <p className="text-3xl font-extrabold tabular" style={{ color: "var(--on-surface)" }}>
                  {latest?.weight} <span className="text-base" style={{ color: "var(--on-surface-variant)" }}>kg</span>
                </p>
              </div>
              <SegmentedControl options={RANGE_OPTIONS} value={range} onChange={setRange} size="sm" />
            </div>
            {chartData.length > 0 ? (
              <TimeSeriesChart data={chartData} color="var(--metric-weight)" unit=" kg" />
            ) : (
              <p className="text-sm text-center py-12" style={{ color: "var(--muted)" }}>No data in this range</p>
            )}
          </div>

          {/* History */}
          <div className="w-full lg:w-[300px] shrink-0 rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
            <p className="text-sm font-bold mb-3">History</p>
            <div className="flex flex-col">
              {history.map((w, idx) => {
                // delta vs the next older entry (history is newest-first)
                const older = history[idx + 1] as WeightResponse | undefined;
                const delta = older ? w.weight - older.weight : null;
                return (
                  <div key={w.id} className="flex items-center justify-between py-2 group"
                    style={{ borderBottom: "1px solid var(--outline)" }}>
                    <span className="text-sm tabular" style={{ color: "var(--on-surface-variant)" }}>
                      {format(new Date(w.date), "MMM d, yyyy")}
                    </span>
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-semibold tabular">{w.weight} kg</span>
                      {delta != null && delta !== 0 && (
                        <span className="text-xs tabular font-semibold"
                          style={{ color: delta < 0 ? "var(--goal-positive)" : "var(--goal-negative)" }}>
                          {delta > 0 ? "+" : ""}{delta.toFixed(1)}
                        </span>
                      )}
                      <button onClick={() => deleteMutation.mutate(w.id)}
                        className="opacity-0 group-hover:opacity-100 transition-opacity" style={{ color: "var(--muted)" }}
                        aria-label="Delete entry">
                        <span className="material-symbols-rounded text-base">close</span>
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
