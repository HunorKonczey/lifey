"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { waterApi } from "@/features/water/api";
import type { WaterSourceResponse } from "@/features/water/types";
import { queryKeys } from "@/lib/api/queryKeys";
import { logTimestampFor } from "@/lib/utils/logTime";

interface WaterCardProps {
  currentLiters: number;
  goalLiters: number;
  sources: WaterSourceResponse[];
  /** The day this card logs against; defaults to now. */
  date?: Date;
}

const SEGMENTS = 8;

export function WaterCard({ currentLiters, goalLiters, sources, date }: WaterCardProps) {
  const queryClient = useQueryClient();
  const filled = goalLiters > 0 ? Math.min(currentLiters / goalLiters, 1) : 0;
  const filledSegments = Math.round(filled * SEGMENTS);

  const addMutation = useMutation({
    mutationFn: ({ volumeLiters, sourceId }: { volumeLiters: number; sourceId?: number | null }) =>
      waterApi.entries.create({ consumedAt: logTimestampFor(date), volumeLiters, sourceId }),
    onMutate: async ({ volumeLiters }) => {
      // optimistic update
      await queryClient.cancelQueries({ queryKey: queryKeys.waterEntries.all() });
      const prev = queryClient.getQueryData(queryKeys.waterEntries.all());
      queryClient.setQueryData(queryKeys.waterEntries.all(), (old: { volumeLiters: number }[] = []) => [
        ...old,
        { id: Date.now(), consumedAt: logTimestampFor(date), volumeLiters, sourceId: null, sourceName: null },
      ]);
      return { prev };
    },
    onError: (_err, _vars, ctx) => {
      if (ctx?.prev !== undefined) {
        queryClient.setQueryData(queryKeys.waterEntries.all(), ctx.prev);
      }
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.waterEntries.all() });
    },
  });

  const quickSources = sources.length > 0
    ? sources.slice(0, 3)
    : [
        { id: -1, name: "Glass", volumeLiters: 0.25 },
        { id: -2, name: "Bottle", volumeLiters: 0.5 },
      ];

  return (
    <div className="flex flex-col gap-4 p-4 rounded-[var(--r-card)]" style={{ background: "var(--surface)" }}>
      <div className="flex items-center gap-2">
        <span
          className="material-symbols-rounded text-xl"
          style={{ color: "var(--metric-water)", fontVariationSettings: "'FILL' 1" }}
        >
          water_drop
        </span>
        <span className="text-sm font-semibold" style={{ color: "var(--on-surface-variant)" }}>Water</span>
        <span className="ml-auto text-sm font-bold tabular">
          {currentLiters.toFixed(1)} <span style={{ color: "var(--on-surface-variant)" }}>/ {goalLiters.toFixed(1)} L</span>
        </span>
      </div>

      {/* Segment glasses */}
      <div className="flex items-end gap-1">
        {Array.from({ length: SEGMENTS }).map((_, i) => (
          <div
            key={i}
            className="flex-1 rounded-[var(--r-sm)] transition-all duration-[var(--dur-base)]"
            style={{
              height: 28 + (i / SEGMENTS) * 8,
              background: i < filledSegments ? "var(--metric-water)" : "var(--surface-highest)",
            }}
          />
        ))}
      </div>

      {/* Quick-add buttons */}
      <div className="flex gap-2">
        {quickSources.map((src) => (
          <button
            key={src.id}
            onClick={() => addMutation.mutate({ volumeLiters: src.volumeLiters, sourceId: src.id > 0 ? src.id : null })}
            disabled={addMutation.isPending}
            className="flex-1 py-1.5 rounded-[var(--r-input)] text-xs font-semibold transition-opacity disabled:opacity-50"
            style={{
              background: "var(--surface-container)",
              color: "var(--metric-water)",
              border: "1px solid var(--outline)",
            }}
          >
            +{src.volumeLiters >= 1
              ? `${src.volumeLiters}L`
              : `${Math.round(src.volumeLiters * 1000)}ml`}{" "}
            {src.name}
          </button>
        ))}
      </div>
    </div>
  );
}
