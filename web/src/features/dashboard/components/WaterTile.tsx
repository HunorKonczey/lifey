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

/** The "⋯" menu to the water page. Rendered twice — a 32px header button on a
 *  narrow (2-up, phone) tile, a 40px footer button beside the quick adds once the
 *  tile is wide enough — and shown/hidden by the tile's own container width. */
function WaterMenu({ className, size }: { className: string; size: number }) {
  const t = useTranslations("dashboard");
  const router = useRouter();
  const anchor = useRef<HTMLButtonElement>(null);
  const [open, setOpen] = useState(false);

  return (
    <>
      <button
        ref={anchor}
        type="button"
        aria-label={t("waterMenuLabel")}
        aria-haspopup="menu"
        aria-expanded={open}
        onClick={() => setOpen(true)}
        className={["lifey-button items-center justify-center shrink-0", className].join(" ")}
        style={{
          width: size,
          height: size,
          borderRadius: "var(--r-control)",
          background: size >= 40 ? "var(--nested)" : "transparent",
          color: "var(--text-2)",
        }}
      >
        <Icon name="more_horiz" size={20} />
      </button>
      <Menu
        open={open}
        onClose={() => setOpen(false)}
        anchorRef={anchor}
        items={[
          { label: t("waterManageSources"), icon: "tune", onSelect: () => router.push("/water#sources") },
          { label: t("waterOpenPage"), icon: "water_drop", onSelect: () => router.push("/water") },
        ]}
      />
    </>
  );
}

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
  const queryClient = useQueryClient();

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
      unitRatio={0.6}
      color="var(--metric-water)"
      segments={{ count: 10, progress, height: 8 }}
      aria-label={fmt.litresOfGoal(totals.waterL, goal)}
      actions={<WaterMenu className="@[200px]:hidden" size={32} />}
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
          <WaterMenu className="hidden @[200px]:inline-flex" size={40} />
        </div>
      }
    />
  );
}
