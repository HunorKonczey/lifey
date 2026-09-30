"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { Icon, MetricTile } from "@/components/ds";
import { Menu } from "@/components/ds/Menu";
import { waterApi } from "@/features/water/api";
import { rankQuickSources, type QuickSource } from "@/features/water/quickSources";
import type { WaterEntryResponse } from "@/features/water/types";
import { queryKeys } from "@/lib/api/queryKeys";
import { useFormat } from "@/lib/format/useFormat";
import { useToast } from "@/lib/hooks/useToast";
import { logTimestampFor } from "@/lib/utils/logTime";
import type { DashboardData } from "../useDashboardData";

/**
 * The dashboard's water tile (W1.5): litres against the goal on the 10
 * segments, "last 14:10", and two quick-add buttons — the user's two most used
 * sources (`rankQuickSources`, falling back to 0.25 / 0.5 L) that log an entry
 * straight away — plus a "⋯" menu to the water page. The add is optimistic:
 * the segments fill by the delta immediately and roll back on failure.
 */
export function WaterTile({ data }: { data: DashboardData }) {
  const t = useTranslations("dashboard");
  const fmt = useFormat();
  const router = useRouter();
  const queryClient = useQueryClient();
  const menuAnchor = useRef<HTMLButtonElement>(null);
  const [menuOpen, setMenuOpen] = useState(false);

  const { settings, totals, todayWater, date, queries } = data;
  const goal = settings?.dailyWaterGoalLiters ?? 2.5;
  const entries = (queries.waterEntriesQ.data as WaterEntryResponse[] | undefined) ?? [];
  const quick = rankQuickSources(entries, queries.waterSourcesQ.data ?? [], new Date());

  const lastAt = todayWater.length > 0 ? new Date(Math.max(...todayWater.map((e) => new Date(e.consumedAt).getTime()))) : null;

  const add = useMutation({
    mutationFn: ({ volumeLiters, sourceId }: QuickSource) =>
      waterApi.entries.create({ consumedAt: logTimestampFor(date), volumeLiters, sourceId }),
    onMutate: async ({ volumeLiters, sourceId }) => {
      await queryClient.cancelQueries({ queryKey: queryKeys.waterEntries.all() });
      const previous = queryClient.getQueryData(queryKeys.waterEntries.all());
      queryClient.setQueryData(queryKeys.waterEntries.all(), (old: WaterEntryResponse[] = []) => [
        ...old,
        { id: -Date.now(), consumedAt: logTimestampFor(date), volumeLiters, sourceId, sourceName: null },
      ]);
      return { previous };
    },
    onError: (_err, _vars, ctx) => {
      if (ctx?.previous !== undefined) queryClient.setQueryData(queryKeys.waterEntries.all(), ctx.previous);
      useToast.getState().show(t("waterAddFailed"), "error");
    },
    onSettled: () => queryClient.invalidateQueries({ queryKey: queryKeys.waterEntries.all() }),
  });

  const progress = goal > 0 ? totals.waterL / goal : 0;

  return (
    <MetricTile
      icon="water_drop"
      label={t("water")}
      meta={lastAt ? t("waterLastAt", { time: fmt.time(lastAt) }) : undefined}
      value={fmt.litreNumber(totals.waterL)}
      unit={`/ ${fmt.litres(goal)}`}
      color="var(--metric-water)"
      segments={{ count: 10, progress, height: 8 }}
      aria-label={fmt.litresOfGoal(totals.waterL, goal)}
      footer={
        <div className="flex gap-2">
          {quick.map((q) => (
            <button
              key={q.sourceId ?? `default-${q.volumeLiters}`}
              type="button"
              onClick={() => add.mutate(q)}
              aria-label={t("waterQuickAdd", { volume: fmt.litres(q.volumeLiters) })}
              className="lifey-button flex-1 type-button"
              style={{
                height: 40,
                borderRadius: "var(--r-control)",
                background: "color-mix(in srgb, var(--metric-water) 16%, transparent)",
                color: "var(--metric-water)",
                fontWeight: 700,
                fontSize: 14,
              }}
            >
              + {fmt.litres(q.volumeLiters)}
            </button>
          ))}
          <button
            ref={menuAnchor}
            type="button"
            aria-label={t("waterMenuLabel")}
            aria-haspopup="menu"
            aria-expanded={menuOpen}
            onClick={() => setMenuOpen(true)}
            className="lifey-button inline-flex items-center justify-center shrink-0"
            style={{ width: 40, height: 40, borderRadius: "var(--r-control)", background: "var(--nested)", color: "var(--text-2)" }}
          >
            <Icon name="more_horiz" size={20} />
          </button>
          <Menu
            open={menuOpen}
            onClose={() => setMenuOpen(false)}
            anchorRef={menuAnchor}
            items={[
              { label: t("waterManageSources"), icon: "tune", onSelect: () => router.push("/water#sources") },
              { label: t("waterOpenPage"), icon: "water_drop", onSelect: () => router.push("/water") },
            ]}
          />
        </div>
      }
    />
  );
}
