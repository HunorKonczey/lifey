"use client";

import { useEffect, useMemo, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { format } from "date-fns";
import { ConfirmModal, GridItem, PageGrid } from "@/components/ds";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";
import { settingsApi } from "@/features/settings/api";
import { waterApi } from "@/features/water/api";
import { WaterEntriesList } from "@/features/water/components/WaterEntriesList";
import { WaterHero, type WaterTile } from "@/features/water/components/WaterHero";
import { WaterSourcesDrawer } from "@/features/water/components/WaterSourcesDrawer";
import { WaterTrendCard } from "@/features/water/components/WaterTrendCard";
import { PAGE_QUICK_VOLUMES, rankQuickSources, type QuickSource } from "@/features/water/quickSources";
import type { WaterEntryResponse } from "@/features/water/types";
import { waterWindow } from "@/features/water/waterStats";
import { queryKeys } from "@/lib/api/queryKeys";
import { useDateStore } from "@/lib/hooks/useDateStore";
import { TOAST_DURATION_MS, useToast } from "@/lib/hooks/useToast";
import { useUndoableDelete } from "@/lib/hooks/useUndoableDelete";
import { useFormat } from "@/lib/format/useFormat";
import { logTimestampFor } from "@/lib/utils/logTime";

/** The default containers' names by volume — a saved source brings its own. */
const DEFAULT_NAME_KEY: Record<string, string> = { "0.25": "defaultGlass", "0.5": "defaultBottle", "0.33": "defaultCan", "1": "defaultLitre" };

/**
 * The water page (W4.5, W4-B): hero with the ring and four source tiles on the left, the day's entries on the right,
 * "Az elmúlt 14 nap" across the bottom. The day comes from the top bar's date stepper; "/water#sources" (the
 * dashboard tile's menu) opens the sources drawer.
 */
export default function WaterPage() {
  const t = useTranslations("water");
  const common = useTranslations("common");
  const fmt = useFormat();
  const { date } = useDateStore();
  const queryClient = useQueryClient();
  const { show } = useToast();
  const undoableDelete = useUndoableDelete();
  const dateStr = format(date, "yyyy-MM-dd");
  const [managing, setManaging] = useState(false);
  const [deleting, setDeleting] = useState<WaterEntryResponse | null>(null);

  const entriesQ = useQuery({ queryKey: queryKeys.waterEntries.all(), queryFn: waterApi.entries.list });
  const sourcesQ = useQuery({ queryKey: queryKeys.waterSources.all(), queryFn: waterApi.sources.list });
  const settingsQ = useQuery({ queryKey: queryKeys.settings.all(), queryFn: settingsApi.get, staleTime: 5 * 60_000 });

  // "/water#sources" — the dashboard tile's "Vízforrások kezelése" — opens the drawer once.
  useEffect(() => {
    if (window.location.hash === "#sources") {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- one-shot deep link
      setManaging(true);
      history.replaceState(null, "", window.location.pathname);
    }
  }, []);

  const entries = useMemo(() => entriesQ.data ?? [], [entriesQ.data]);
  const sources = useMemo(() => sourcesQ.data ?? [], [sourcesQ.data]);
  const dayEntries = entries.filter((e) => format(new Date(e.consumedAt), "yyyy-MM-dd") === dateStr);
  const total = dayEntries.reduce((s, e) => s + e.volumeLiters, 0);
  const goal = settingsQ.data?.dailyWaterGoalLiters ?? 2.5;
  const now = new Date();

  const ranked = rankQuickSources(entries, sources, now, 4, PAGE_QUICK_VOLUMES);
  const tiles: WaterTile[] = ranked.map((source) => ({
    source,
    name: source.sourceId != null ? (sources.find((s) => s.id === source.sourceId)?.name ?? t("entryLabel")) : t(DEFAULT_NAME_KEY[String(source.volumeLiters)] ?? "defaultGlass"),
  }));
  const containerLiters = ranked[0]?.volumeLiters ?? 0.25;

  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const windowEnd = date.getTime() > today.getTime() ? today : date;
  const trend = waterWindow(entries, goal, windowEnd, now);

  const addMutation = useMutation({
    mutationFn: ({ volumeLiters, sourceId }: QuickSource) => waterApi.entries.create({ consumedAt: logTimestampFor(date), volumeLiters, sourceId }),
    onMutate: async ({ volumeLiters, sourceId }) => {
      await queryClient.cancelQueries({ queryKey: queryKeys.waterEntries.all() });
      const prev = queryClient.getQueryData(queryKeys.waterEntries.all());
      queryClient.setQueryData(queryKeys.waterEntries.all(), (old: WaterEntryResponse[] = []) => [
        ...old,
        { id: -Date.now(), consumedAt: logTimestampFor(date), volumeLiters, sourceId: sourceId ?? null, sourceName: sources.find((s) => s.id === sourceId)?.name ?? null },
      ]);
      return { prev };
    },
    onError: (_e, _v, ctx) => {
      if (ctx?.prev !== undefined) queryClient.setQueryData(queryKeys.waterEntries.all(), ctx.prev);
      show(t("addFailed"), "error");
    },
    onSettled: () => queryClient.invalidateQueries({ queryKey: queryKeys.waterEntries.all() }),
  });

  // Delete = confirm → the entry leaves the list and a toast offers Undo; the DELETE goes out when the window closes.
  const setCached = (update: (list: WaterEntryResponse[]) => WaterEntryResponse[]) =>
    queryClient.setQueryData<WaterEntryResponse[]>(queryKeys.waterEntries.all(), (old) => update(old ?? []));
  const deleteEntry = (entry: WaterEntryResponse) =>
    undoableDelete({
      message: t("entryDeletedUndo", { litres: fmt.litres(entry.volumeLiters) }),
      path: `/water-entries/${entry.id}`,
      remove: () => setCached((list) => list.filter((e) => e.id !== entry.id)),
      restore: () => setCached((list) => (list.some((e) => e.id === entry.id) ? list : [...list, entry])),
      errorMessage: t("removeFailed"),
    });

  if (entriesQ.isLoading || sourcesQ.isLoading) {
    return (
      <PageGrid>
        <GridItem span={{ base: 4, md: 8, xl: 6 }}>
          <Skeleton variant="card" className="h-96" />
        </GridItem>
        <GridItem span={{ base: 4, md: 8, xl: 6 }}>
          <Skeleton variant="card" className="h-96" />
        </GridItem>
      </PageGrid>
    );
  }
  if (entriesQ.isError) return <ErrorState onRetry={() => entriesQ.refetch()} />;

  const isToday = format(date, "yyyy-MM-dd") === format(now, "yyyy-MM-dd");

  return (
    <div className="flex flex-col gap-5">
      <PageGrid>
        <GridItem span={{ base: 4, md: 8, xl: 6 }}>
          <WaterHero
            total={total}
            goal={goal}
            tiles={tiles}
            containerLiters={containerLiters}
            pending={addMutation.isPending}
            onAdd={(source) => addMutation.mutate(source)}
            onManage={() => setManaging(true)}
          />
        </GridItem>
        <GridItem span={{ base: 4, md: 8, xl: 6 }}>
          <WaterEntriesList entries={dayEntries} title={isToday ? t("entriesToday") : t("entriesOn", { date: fmt.shortDate(date) })} onDelete={setDeleting} />
        </GridItem>
        <GridItem span={{ base: 4, md: 8, xl: 12 }}>
          <WaterTrendCard window={trend} goal={goal} />
        </GridItem>
      </PageGrid>

      {managing && <WaterSourcesDrawer sources={sources} onClose={() => setManaging(false)} />}

      <ConfirmModal
        open={deleting != null}
        onClose={() => setDeleting(null)}
        onConfirm={() => {
          if (deleting) deleteEntry(deleting);
          setDeleting(null);
        }}
        icon="delete"
        title={deleting ? t("deleteEntryTitle", { litres: fmt.litres(deleting.volumeLiters) }) : ""}
        body={t("deleteEntryBody", { seconds: TOAST_DURATION_MS / 1000 })}
        cancelLabel={common("cancel")}
        confirmLabel={common("delete")}
      />
    </div>
  );
}
